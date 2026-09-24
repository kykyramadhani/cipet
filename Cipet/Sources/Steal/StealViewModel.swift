import SwiftUI

enum Steal {
    static let round: Double = 90        // seconds on the clock
    static let grabTime: Double = 7      // how long you have to hold to lift the item
    static let slip: Double = 0.08       // the bar sags when you let go, but slowly

    /// how fast somebody catches on while your hand's in. the animated ones go by their
    /// mood: headphones on or asleep is slow, once they're looking about it's quick.
    static func awareRate(_ rider: Rider?, _ mood: Mood?) -> Double {
        switch mood {
        case .alert?, .angry?: return 0.30
        case .calm?:           return rider == .sleepy ? 0.07 : 0.10
        case nil:              return rider == nil ? 0.18 : 0.20   // the kid, or a flat passenger
        }
    }
    /// a little different per seat, so two of the same passenger dont fill in step
    static let seatNudge: [Seating.Person: Double] = [.farLeft: 1.0, .farMid: 1.12, .farRight: 0.9,
                                                      .nearLeft: 1.06, .nearMid: 0.94, .nearRight: 1.1]
    /// a calm passenger looks up once they're this suspicious
    static let alertAt: CGFloat = 0.5
    /// and everyone settles down this fast once you stop
    static let awareCalm: Double = 0.30

    static let penalty: Double = 3       // seconds frozen after somebody clocks you
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
    private(set) var penaltyLeft = 0.0
    /// how far the road has scrolled, 0..<1 of one screen width
    private(set) var road: CGFloat = 0

    /// finger is down on the bar
    var holding = false

    private var resumeTo: Phase = .stealing

    init(victim: Seating.Person, thiefSeat: CGRect, cast: Arrangement) {
        self.victim = victim
        self.thiefSeat = thiefSeat
        self.cast = cast
        // everyone gets a bar, whoever you're robbing included
        for who in cast.watchers { aware[who] = 0 }
        moods = cast.start
    }

    var clock: String { mmss(timeLeft.rounded(.up)) }
    var running: Bool { phase == .stealing }
    var stopFor: Int { max(1, Int(penaltyLeft.rounded(.up))) }
    var over: Bool { phase == .succeeded || phase == .caught }

    func tick(_ dt: Double) {
        guard phase != .paused, !over else { return }

        // we're driving the whole time we're aboard, cooldown included
        road = (road + CGFloat(dt / Steal.roadLoop)).truncatingRemainder(dividingBy: 1)

        // the clock keeps running through the penalty, only the stealing stops
        timeLeft -= dt
        if timeLeft <= 0 { timeLeft = 0; caught(); return }

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
            let rate = holding
                ? Steal.awareRate(cast.who(who), moods[who]) * (Steal.seatNudge[who] ?? 1)
                : -Steal.awareCalm
            let next = (aware[who] ?? 0) + CGFloat(dt * rate)

            if next >= 1 {
                aware[who] = 0          // they look away again, but the damage is done
                spotted(by: who)
                return
            }
            aware[who] = max(0, next)
            if moods[who] == .calm, next >= Steal.alertAt { moods[who] = .alert }
        }
    }

    /// one full aware bar is one strike, never a trickle. whoever it was settles back down.
    private func spotted(by who: Seating.Person) {
        suspicion += 1
        holding = false
        if moods[who] != nil { moods[who] = .calm }
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

    // holding, easing off before anyone fills up, then holding again does land it
    var win = StealViewModel(victim: .farLeft, thiefSeat: seat, cast: fixed)
    while !win.over && win.timeLeft > 1 {
        win.holding = (win.aware.values.max() ?? 0) < 0.55
        win.tick(1.0 / 60)
    }
    assert(win.phase == .succeeded, "easing off in time has to be a way to win")
    assert(win.suspicion == 0, "and it shouldnt cost a strike")

    // a full aware bar is exactly one strike, and it freezes you rather than ending it
    var s = StealViewModel(victim: .farLeft, thiefSeat: seat, cast: fixed)
    s.holding = true
    while s.suspicion == 0 && !s.over { s.tick(1.0 / 60) }
    assert(s.suspicion == 1, "one full bar, one strike")
    assert(s.phase == .penalty && s.penaltyLeft > 0)
    assert(!s.holding, "getting spotted makes you let go")
    let before = s.grab
    for _ in 0..<30 { s.tick(1.0 / 60) }
    assert(s.grab == before, "the steal bar is frozen while you're told to stop")
    assert(s.timeLeft < Steal.round, "but the clock keeps going")

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
    assert(c.suspicion == Steal.strikes && c.phase == .caught)

    // the target has a bar of their own, and so does the kid
    let bars = StealViewModel(victim: .farLeft, thiefSeat: seat, cast: fixed)
    assert(bars.aware[.farLeft] != nil && bars.aware[.kid] != nil && bars.aware.count == 4)

    // moods, with one music passenger (who's also the mark) and the kid. music calm fills at
    // 0.10 and the kid at 0.18, so music looks up at 5s, the kid clocks you at 5.6s, then
    // music, now quick, is the next to fill.
    let solo = Arrangement(cast: [.farLeft: .music], start: [.farLeft: .calm])
    var m = StealViewModel(victim: .farLeft, thiefSeat: solo.seats(beside: .farLeft)[0], cast: solo)
    assert(Steal.awareRate(.music, .alert) > Steal.awareRate(.music, .calm) * 2,
           "headphones off, they catch on a lot faster")
    let step = { (m: inout StealViewModel) in m.holding = m.running; m.tick(1.0 / 60) }
    while m.moods[.farLeft] == .calm { step(&m) }
    assert(m.suspicion == 0 && m.aware[.farLeft]! >= Steal.alertAt, "half way suspicious, they look up")
    while m.suspicion == 0 { step(&m) }
    assert(m.moods[.farLeft] == .alert, "the kid spotted you, music is still looking about")
    while m.suspicion == 1 { step(&m) }
    assert(m.moods[.farLeft] == .calm, "music spotted you, and settles back down")
    while !m.over { m.holding = false; m.tick(1) }   // hands off, and let the clock run out
    assert(m.phase == .caught && m.moods[.farLeft] == .angry, "caught, and they turn on you")

    // a packed angkot with both animated faces starting alert can still be won by easing off
    let crowd = Arrangement(cast: [.farLeft: .music, .farMid: .frontA, .farRight: .sleepy,
                                   .nearLeft: .backA, .nearMid: .backA],
                            start: [.farLeft: .alert, .farRight: .alert])
    var hard = StealViewModel(victim: .nearMid, thiefSeat: crowd.seats(beside: .nearMid)[0], cast: crowd)
    while !hard.over && hard.timeLeft > 1 {
        hard.holding = (hard.aware.values.max() ?? 0) < 0.55
        hard.tick(1.0 / 60)
    }
    assert(hard.phase == .succeeded, "the fullest angkot still has to be beatable")

    // the clock running out ends it too
    var t = StealViewModel(victim: .nearMid, thiefSeat: seat, cast: fixed)
    while t.timeLeft > 0 { t.tick(1) }
    assert(t.phase == .caught)
    #endif
}
