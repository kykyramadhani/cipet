import SwiftUI

enum Steal {
    static let round: Double = 60        // seconds on the clock
    static let warn:  Double = 10        // the clock goes red for the last stretch
    static let grabTime: Double = 7      // how long you have to hold to lift the item
    /// the four rates are ordered, and the order is the design: the steal bar is the
    /// sluggish one and a passenger's suspicion is the twitchy one.
    ///   grabRate < slip < awareCalm < every awareRate
    static var grabRate: Double { 1 / grabTime }
    static let slip: Double = 0.16       // the bar sags faster than it fills

    /// how fast a passenger gets suspicious while you're at it, the same on every seat, and
    /// how fast they settle down when you stop
    static let awareRate: Double = 0.22
    static let awareIdle: Double = 0.20  // the kid, who isnt on a seat
    static let awareCalm: Double = 0.18

    static let penalty: Double = 3       // seconds frozen after somebody clocks you
    /// the angkot sits 2 lower here than on the other screens
    static let angkotDrop: CGFloat = 2
    static let roundTag  = CGRect(x: 24, y: 350, width: 140, height: 32)
    static let roundArt  = CGRect(x: 23.328, y: 347.651, width: 140.629, height: 36.0456)
    static let roundSize: CGFloat = 16
    /// the hud sits at 20 here, 4 higher than on pick target
    static let pauseArt  = CGRect(x: 787.498, y: 18.252, width: 65.437, height: 64.748)
    static let strikes = 3               // full aware bars before you're caught

    static let itemValue = 20            // thousands of rupiah

    /// seconds for the road to scroll one screen width. the angkot itself never moves —
    /// the road going past underneath is the whole effect.
    static let roadLoop: Double = 4
}

@Observable final class StealViewModel {
    enum Phase { case stealing, penalty, paused, succeeded, caught }

    let victim: Seating.Person
    let thiefSeat: CGRect
    let cast: Arrangement

    private(set) var phase: Phase = .stealing
    private(set) var grab: CGFloat = 0
    private(set) var aware: [Seating.Person: CGFloat] = [:]
    /// what the animated passengers are up to, which picks their animation
    private(set) var moods: [Seating.Person: Mood] = [:]
    private(set) var suspicion = 0
    private(set) var timeLeft = Steal.round
    /// the clock ran out, as opposed to getting spotted three times
    private(set) var timedOut = false
    private(set) var penaltyLeft = 0.0
    /// how far the road has scrolled, 0..<1 of one screen width
    private(set) var road: CGFloat = 0

    /// finger is down on the bar
    var holding = false

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
    }

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

        if phase == .penalty {
            penaltyLeft -= dt
            if penaltyLeft <= 0 { phase = .stealing }
            return
        }

        advanceGrab(dt)
        advanceAwareness(dt)
    }

    private func advanceGrab(_ dt: Double) {
        if holding {
            grab = min(1, grab + CGFloat(dt / Steal.grabTime))
            if grab >= 1 { phase = .succeeded }
        } else {
            grab = max(0, grab - CGFloat(dt * Steal.slip))
        }
    }

    private func advanceAwareness(_ dt: Double) {
        for who in Array(aware.keys) {
            let rate = holding ? (who == .kid ? Steal.awareIdle : Steal.awareRate) : -Steal.awareCalm
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
    private func caught() {
        phase = .caught
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
    assert(Steal.grabRate < Steal.slip, "the steal bar has to sag faster than it fills")
    assert(Steal.slip < Steal.awareCalm, "and sag slower than a passenger settles down")
    assert(Steal.awareCalm < Steal.awareRate, "who all notice quicker than they settle")
    assert(Steal.awareCalm < Steal.awareIdle, "the kid included")

    // what that ordering costs: easing off can never win on its own. to gain on the bar
    // you have to hold more than slip/(slip+grabRate) of the time, and to keep a bar from
    // filling you have to hold less than awareCalm/(awareCalm+awareRate) of it — and the
    // first is always the larger of the two while slip > grabRate. the strikes are the
    // only slack there is.
    let mustHold = Steal.slip / (Steal.slip + Steal.grabRate)
    let canHold  = Steal.awareCalm / (Steal.awareCalm + Steal.awareRate)
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

    // the bar that fired is left full rather than wiped, and nothing moves while you're held
    assert((s.aware.values.max() ?? 0) == 1, "a bar that just filled is left full")
    let before = s.grab
    for _ in 0..<30 { s.tick(1.0 / 60) }
    assert(s.grab == before, "the steal bar is frozen while you're told to stop")
    assert(s.timeLeft < Steal.round, "but the clock keeps going")
    assert((s.aware.values.max() ?? 0) == 1, "and the bar is still full through the cooldown")

    // only once the cooldown is over does it come down — from full, at the settling rate
    while s.phase == .penalty { s.tick(1.0 / 60) }
    for _ in 0..<30 { s.tick(1.0 / 60) }
    let after = s.aware.values.max() ?? 0
    assert(after < 1, "then it drains")
    assert(abs(after - (1 - 0.5 * Steal.awareCalm)) < 0.01, "from full, not from nothing")
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
    #endif
}
