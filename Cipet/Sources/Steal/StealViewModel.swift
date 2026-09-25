import SwiftUI

enum Steal {
    static let round: Double = 60        // seconds on the clock
    static let warn:  Double = 10        // the clock goes red for the last stretch
    // how fast the bar fills and sags, and how fast each passenger catches on, are dealt per
    // passenger per round now: see Traits. the bar goes by the mark's own numbers.

    static let penalty: Double = 3       // seconds frozen after somebody clocks you
    /// how long everyone's MARAH is held on screen before the cage comes down
    static let angerHold: Double = 0.6
    /// the angkot sits 2 lower here than on the other screens
    static let angkotDrop: CGFloat = 2
    static let roundTag  = CGRect(x: 24, y: 350, width: 140, height: 32)
    static let roundArt  = CGRect(x: 23.328, y: 347.651, width: 140.629, height: 36.0456)
    static let roundSize: CGFloat = 16
    /// the hud sits at 20 here, 4 higher than on pick target
    static let pauseArt  = CGRect(x: 787.498, y: 18.252, width: 65.437, height: 64.748)
    static let strikes = 3               // full aware bars before you're caught

    /// what one lift is worth, in whole rupiah: 5k up to a million, rolled per round
    static let loot = 5_000...1_000_000
    static func rollLoot() -> Int { Int.random(in: loot.lowerBound / 1_000...loot.upperBound / 1_000) * 1_000 }

    /// seconds for the road to scroll one screen width. the angkot itself never moves —
    /// the road going past underneath is the whole effect.
    static let roadLoop: Double = 4
}

@Observable final class StealViewModel {
    enum Phase { case stealing, penalty, paused, succeeded, caught }

    let victim: Seating.Person
    let thiefSeat: CGRect
    let cast: Arrangement
    /// what's in the pocket this round, decided before he reaches for it
    let loot = Steal.rollLoot()

    private(set) var phase: Phase = .stealing
    private(set) var grab: CGFloat = 0
    private(set) var aware: [Seating.Person: CGFloat] = [:]
    /// what each passenger is up to, which picks their animation and whether they're watching
    private(set) var moods: [Seating.Person: Mood] = [:]
    /// seconds until each one switches between idle and their own thing
    private var switchIn: [Seating.Person: Double] = [:]
    /// how long the passengers take to turn on you once you're caught, so the cage waits for it
    private(set) var angerTime: Double = 0
    private(set) var suspicion = 0
    private(set) var timeLeft = Steal.round
    /// the clock ran out, as opposed to getting spotted three times
    private(set) var timedOut = false
    private(set) var penaltyLeft = 0.0
    /// how far the road has scrolled, 0..<1 of one screen width
    private(set) var road: CGFloat = 0

    /// finger is down on the bar
    var holding = false { didSet { if holding { reached = true } } }

    private var resumeTo: Phase = .stealing

    /// the clock is the round's, not this screen's — it has already been running while
    /// the seat was being picked, so the round carries on from wherever it got to.
    init(victim: Seating.Person, thiefSeat: CGRect, cast: Arrangement,
         timeLeft: Double = Steal.round) {
        self.victim = victim
        self.thiefSeat = thiefSeat
        self.cast = cast
        self.timeLeft = max(0, timeLeft)
        // everyone gets a bar, whoever you're robbing included
        for who in cast.watchers { aware[who] = 0 }
        moods = cast.start
        for who in cast.watchers { switchIn[who] = hold(who) }
    }

    /// the mark's numbers drive the steal bar
    private var mark: Traits { cast.traits(victim) }

    /// no bars until his hand first goes in: the first hold is what starts the stealing.
    /// then everyone's bar is up, and after that a bar shows while they're idle and while it
    /// drains once they drift off; empty and off in their own thing, it's gone until they're
    /// idle again. drawn against their own threshold, so it reads full as they clock you.
    var bars: [Seating.Person: CGFloat] {
        guard reached else { return [:] }
        return aware.filter { moods[$0.key] == .alert || $0.value > 0 || !driftedOff.contains($0.key) }
    }
    /// whether he's held yet this round
    private(set) var reached = false
    /// who has drifted off since the round started, which is what lets their bar go
    private var driftedOff: Set<Seating.Person> = []

    var clock: String { mmss(timeLeft.rounded(.up)) }
    /// the last few seconds, which the hud draws in red
    var lowOnTime: Bool { timeLeft <= Steal.warn }
    var running: Bool { phase == .stealing }
    var stopFor: Int { max(1, Int(penaltyLeft.rounded(.up))) }
    var over: Bool { phase == .succeeded || phase == .caught }

    func tick(_ dt: Double) {
        guard phase != .paused, !over else { return }

        // we're driving the whole time we're aboard, cooldown included
        road = (road + CGFloat(dt / Steal.roadLoop)).truncatingRemainder(dividingBy: 1)

        // the clock keeps running through the penalty, only the stealing stops
        timeLeft -= dt
        if timeLeft <= 0 { timeLeft = 0; timedOut = true; caught(); return }

        // they carry on with their lives through a cooldown too
        advanceExpressions(dt)

        // the cooldown only stops you stealing. you've let go, so the steal bar sags exactly
        // as it does whenever you let go, and everyone's suspicion keeps settling
        if phase == .penalty {
            penaltyLeft -= dt
            if penaltyLeft <= 0 { phase = .stealing }
        }

        advanceGrab(dt)
        advanceAwareness(dt)
    }

    private func advanceGrab(_ dt: Double) {
        if holding {
            grab = min(1, grab + CGFloat(dt * mark.grabRate))
            if grab >= 1 { phase = .succeeded }
        } else {
            grab = max(0, grab - CGFloat(dt * mark.slip))
        }
    }

    /// idle -> their own thing -> idle, each on their own clock. the kid never drifts off, and a
    /// duo's right half does whatever the left half does, since it's one conversation.
    private func advanceExpressions(_ dt: Double) {
        for who in cast.watchers where who != .kid && cast.who(who)?.isRightHalf == false {
            switchIn[who, default: 0] -= dt
            guard switchIn[who]! <= 0 else { continue }
            let now: Mood = moods[who] == .alert ? .calm : .alert
            moods[who] = now
            if now == .calm { driftedOff.insert(who) }
            switchIn[who] = hold(who)
            if let right = Seating.right(of: who), cast.who(right)?.isRightHalf == true {
                moods[right] = now
                if now == .calm { driftedOff.insert(right) }
            }
        }
    }

    private func hold(_ who: Seating.Person) -> Double {
        let t = cast.traits(who)
        return .random(in: moods[who] == .alert ? t.idleFor : t.calmFor)
    }

    /// only an idle passenger is watching. in their own thing they notice nothing at all, and
    /// whatever they'd built up drains away.
    private func advanceAwareness(_ dt: Double) {
        for who in Array(aware.keys) {
            let t = cast.traits(who)
            let watching = moods[who] == .alert && holding
            let rate = watching ? t.awareRate / Double(t.threshold) : -t.awareCalm
            let was = aware[who] ?? 0
            let next = min(1, max(0, was + CGFloat(dt * rate)))
            aware[who] = next

            // a bar that has just come up full is the strike. it then sits there full for
            // the cooldown and drains from full once play resumes — it never snaps back to
            // empty, so whoever you woke up is still the one watching you hardest.
            if next >= 1, was < 1 {
                spotted()
                return
            }
        }
    }

    /// one full aware bar is one strike, never a trickle
    private func spotted() {
        suspicion += 1
        holding = false
        if suspicion >= Steal.strikes {
            caught()
        } else {
            phase = .penalty
            penaltyLeft = Steal.penalty
        }
    }

    /// the end of it, and everyone who can get angry does, not just whoever you were robbing
    /// the end of it. spotted three times, everyone who can get angry does — the only way
    /// anybody ever gets angry. running out of time is nobody catching you, so nobody does.
    private func caught() {
        phase = .caught
        guard !timedOut else { return }
        angerTime = cast.watchers.compactMap { who in
            cast.who(who).map { $0.moves.time(from: moods[who] ?? .alert, to: .angry) }
        }.max() ?? 0
        for who in moods.keys { moods[who] = .angry }
    }

    func pause() {
        guard !over, phase != .paused else { return }
        resumeTo = phase
        holding = false
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        phase = resumeTo
    }
}

func runStealChecks() {
    #if DEBUG
    let fixed = Arrangement.fixed
    let seat = fixed.seats(beside: .farLeft)[0]

    // you cant just hold it down. somebody clocks you before the bar fills.
    var greedy = StealViewModel(victim: .farLeft, thiefSeat: seat, cast: fixed)
    greedy.holding = true
    while greedy.phase == .stealing { greedy.tick(1.0 / 60) }
    assert(greedy.suspicion == 1 && greedy.grab < 1, "one long hold has to get you spotted")

    // the four rates are ordered, and everything about how a round plays falls out of it
    // (the dealt ones are checked the same way over a hundred rounds in runSessionChecks)
    let st = Traits.steady
    assert(st.grabRate < st.slip && st.slip < st.awareCalm && st.awareCalm < st.awareRate)

    // what that ordering costs: easing off can never win on its own. to gain on the bar
    // you have to hold more than slip/(slip+grabRate) of the time, and to keep a bar from
    // filling you have to hold less than awareCalm/(awareCalm+awareRate) of it — and the
    // first is always the larger of the two while slip > grabRate. the strikes are the
    // only slack there is.
    let mustHold = st.slip / (st.slip + st.grabRate)
    let canHold  = st.awareCalm / (st.awareCalm + st.awareRate)
    assert(mustHold > canHold, "the ordering is what makes the round cost you strikes")

    var eased = StealViewModel(victim: .farLeft, thiefSeat: seat, cast: fixed)
    while !eased.over && eased.timeLeft > 1 {
        eased.holding = (eased.aware.values.max() ?? 0) < 0.55
        eased.tick(1.0 / 60)
    }
    assert(eased.phase != .succeeded, "which is to say easing off alone cant land it")

    // a full aware bar is exactly one strike, and it freezes you rather than ending it
    var s = StealViewModel(victim: .farLeft, thiefSeat: seat, cast: fixed)
    s.holding = true
    while s.suspicion == 0 && !s.over { s.tick(1.0 / 60) }
    assert(s.suspicion == 1, "one full bar, one strike")
    assert(s.phase == .penalty && s.penaltyLeft > 0)
    assert(!s.holding, "getting spotted makes you let go")

    // through the cooldown nothing is frozen: the bar that fired drains from full at the
    // settling rate, and the steal bar sags at slip, the same as letting go
    assert((s.aware.values.max() ?? 0) == 1, "a bar that just filled is left full")
    let before = s.grab, cooling = s.penaltyLeft
    for _ in 0..<30 { s.tick(1.0 / 60) }
    assert(s.phase == .penalty && abs(s.penaltyLeft - (cooling - 0.5)) < 0.001, "the cooldown runs as it did")
    assert(abs(s.grab - max(0, before - 0.5 * st.slip)) < 0.001, "the steal bar sags at slip")
    assert(abs((s.aware.values.max() ?? 0) - (1 - 0.5 * st.awareCalm)) < 0.01, "suspicion drains from full")
    assert(s.timeLeft < Steal.round, "and the clock keeps going")
    while s.phase == .penalty { s.tick(1.0 / 60) }
    assert(s.suspicion == 1, "and coming down is not another strike")

    // pause preserves everything and resumes where it left off
    var p = StealViewModel(victim: .nearMid, thiefSeat: fixed.seats(beside: .nearMid)[0], cast: fixed)
    p.holding = true
    for _ in 0..<60 { p.tick(1.0 / 60) }
    let held = (p.grab, p.timeLeft, p.aware, p.road)
    assert(p.road > 0, "the road should be moving while he's stealing")
    p.pause()
    for _ in 0..<120 { p.tick(1.0 / 60) }
    assert(p.grab == held.0 && p.timeLeft == held.1 && p.aware == held.2, "pause freezes the lot")
    assert(p.road == held.3, "including the road")
    p.resume()
    assert(p.phase == .stealing)
    p.tick(1.0 / 60)
    assert(p.road > held.3, "and it picks up where it left off rather than starting over")

    // it drives through a cooldown, wraps cleanly, and stops once the round is over
    var r = StealViewModel(victim: .farLeft, thiefSeat: seat, cast: fixed)
    r.holding = true
    while r.phase == .stealing { r.tick(1.0 / 60) }
    let mid = r.road
    for _ in 0..<30 { r.tick(1.0 / 60) }
    // it can lap while we watch, so measure the gap the way the scroll wraps
    let moved = (r.road - mid + 1).truncatingRemainder(dividingBy: 1)
    assert(r.phase == .penalty && moved > 0, "still driving while you're told to stop")
    var laps = StealViewModel(victim: .nearMid, thiefSeat: seat, cast: fixed)
    for _ in 0..<Int(Steal.roadLoop * 60 * 3) {
        laps.tick(1.0 / 60)
        assert(laps.road >= 0 && laps.road < 1, "the scroll has to stay inside one tile")
    }
    var done = StealViewModel(victim: .nearMid, thiefSeat: seat, cast: fixed)
    while done.timeLeft > 0 { done.tick(1) }
    let parked = done.road
    for _ in 0..<60 { done.tick(1.0 / 60) }
    assert(done.road == parked, "once the round is over the angkot has stopped")

    // three strikes and you're caught
    var c = StealViewModel(victim: .farRight, thiefSeat: seat, cast: fixed)
    for _ in 0..<Steal.strikes {
        c.holding = true
        while c.phase == .stealing && !c.over { c.tick(1.0 / 60) }
        while c.phase == .penalty { c.tick(1.0 / 60) }
        while c.grab > 0 && !c.over { c.tick(1.0 / 60) }   // let it sag so the lift never lands
    }
    assert(c.suspicion == Steal.strikes && c.phase == .caught && !c.timedOut, "jailed, not out of time")
    assert(c.moods.values.allSatisfy { $0 == .angry } && c.angerTime > 0,
           "caught, and everyone turns on you, and the cage waits while they do")

    // the target has a bar of their own, and so does the kid
    let bars = StealViewModel(victim: .farLeft, thiefSeat: seat, cast: fixed)
    assert(bars.aware[.farLeft] != nil && bars.aware[.kid] != nil && bars.aware.count == 4)

    // the clock running out ends it too
    var t = StealViewModel(victim: .nearMid, thiefSeat: seat, cast: fixed)
    assert(!t.lowOnTime, "a fresh round is not an emergency")
    while t.timeLeft > Steal.warn { t.tick(1.0 / 60) }
    assert(t.lowOnTime, "the clock has to go red for the last \(Int(Steal.warn)) seconds")
    while t.timeLeft > 0 { t.tick(1) }
    assert(t.phase == .caught && t.timedOut, "out of time is its own ending")
    assert(!t.moods.values.contains(.angry), "nobody caught you, so nobody gets angry")

    // nobody gets angry along the way either, however long a round runs
    var calmRound = StealViewModel(victim: .farLeft, thiefSeat: seat, cast: .random(avoiding: nil))
    while !calmRound.over { calmRound.holding = false; calmRound.tick(1.0 / 30)
        assert(calmRound.over || !calmRound.moods.values.contains(.angry)) }

    // drifted off: noticing nothing, the bar drains, and it's gone once it's empty
    let drifting = Arrangement(cast: fixed.cast, start: [.farLeft: .alert, .farRight: .calm,
                                                        .nearMid: .alert, .kid: .alert],
                               traits: fixed.traits)
    var d = StealViewModel(victim: .nearMid, thiefSeat: fixed.seats(beside: .nearMid)[0], cast: drifting)
    d.holding = true
    for _ in 0..<60 { d.tick(1.0 / 60) }
    assert(StealViewModel(victim: .nearMid, thiefSeat: seat, cast: drifting).bars.isEmpty,
           "no bars at all until the first hold")
    assert(d.aware[.farRight] == 0, "in their own thing they notice nothing")
    assert(d.bars[.farRight] != nil, "but every bar is up from the moment stealing starts")
    var first = StealViewModel(victim: .nearMid, thiefSeat: seat, cast: drifting)
    first.holding = true
    assert(Set(first.bars.keys) == Set(drifting.watchers), "the first hold puts everyone's bar up")
    assert((d.aware[.farLeft] ?? 0) > 0 && d.bars[.farLeft] != nil, "idle: watching, and it shows")

    // the kid never drifts off, and a duo drifts off together
    let duo = Arrangement(cast: [.nearLeft: Rider(who: "BehindLeftDuo"), .nearMid: Rider(who: "BehindRightDuo"),
                                 .farMid: Rider(who: "Music")],
                          start: [.nearLeft: .alert, .nearMid: .alert, .farMid: .alert, .kid: .alert],
                          traits: [.nearLeft: Traits.random(for: Rider(who: "BehindLeftDuo")),
                                   .nearMid: Traits.random(for: Rider(who: "BehindRightDuo")),
                                   .farMid: .steady, .kid: Traits.random(for: .kid)])
    var q = StealViewModel(victim: .farMid, thiefSeat: duo.seats(beside: .farMid)[0], cast: duo)
    var switched = false
    for _ in 0..<(60 * 30) {
        q.tick(1.0 / 60)
        assert(q.moods[.kid] == .alert, "the kid is always idle")
        assert(q.moods[.nearLeft] == q.moods[.nearMid], "one conversation, one mood")
        switched = switched || q.moods[.nearLeft] == .calm
        if q.moods[.nearLeft] == .calm && q.aware[.nearLeft] == 0 {
            assert(q.bars[.nearLeft] == nil, "drifted off and drained: the bar goes")
        }
        if q.over { break }
    }
    assert(switched, "a passenger drifts off at some point in half a minute")

    // a lift is never less than 5k nor more than a million, and always whole thousands
    for _ in 0..<500 {
        let v = Steal.rollLoot()
        assert(Steal.loot.contains(v) && v % 1_000 == 0)
    }

    // the steal bar goes by the mark's own numbers
    let quick = Arrangement(cast: fixed.cast, start: fixed.start, traits: [.farLeft: Traits(
        grabRate: 0.5, slip: 0.6, awareCalm: 0.7, awareRate: 0.8, threshold: 1,
        idleFor: 1e6...1e6, calmFor: 1...2)])
    var g = StealViewModel(victim: .farLeft, thiefSeat: seat, cast: quick)
    g.holding = true
    g.tick(0.5)
    assert(abs(g.grab - 0.25) < 0.001)
    #endif
}
