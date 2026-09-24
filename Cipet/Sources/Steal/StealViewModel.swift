import SwiftUI

enum Steal {
    static let round: Double = 90        // seconds on the clock
    static let grabTime: Double = 7      // how long you have to hold to lift the item
    static let slip: Double = 0.08       // the bar sags when you let go, but slowly

    /// how fast each idle passenger gets suspicious while you're at it, and how fast they
    /// settle down when you stop. different rates so they dont all fill in step.
    static let awareRate: [Seating.Person: Double] = [.farLeft: 0.20, .farRight: 0.26, .near: 0.17]
    static let awareCalm: Double = 0.30

    static let penalty: Double = 3       // seconds frozen after somebody clocks you
    static let strikes = 3               // full aware bars before you're caught

    static let itemValue = 20            // thousands of rupiah
}

@Observable final class StealViewModel {
    enum Phase { case stealing, penalty, paused, succeeded, caught }

    let victim: Seating.Person
    let thiefSeat: CGRect

    private(set) var phase: Phase = .stealing
    private(set) var grab: CGFloat = 0
    private(set) var aware: [Seating.Person: CGFloat] = [:]
    private(set) var suspicion = 0
    private(set) var timeLeft = Steal.round
    private(set) var penaltyLeft = 0.0

    /// finger is down on the bar
    var holding = false

    private var resumeTo: Phase = .stealing

    init(victim: Seating.Person, thiefSeat: CGRect) {
        self.victim = victim
        self.thiefSeat = thiefSeat
        for who in Seating.idle(besides: victim) { aware[who] = 0 }
    }

    var clock: String { mmss(timeLeft.rounded(.up)) }
    var running: Bool { phase == .stealing }
    var stopFor: Int { max(1, Int(penaltyLeft.rounded(.up))) }
    var over: Bool { phase == .succeeded || phase == .caught }

    func tick(_ dt: Double) {
        guard phase != .paused, !over else { return }

        // the clock keeps running through the penalty, only the stealing stops
        timeLeft -= dt
        if timeLeft <= 0 { timeLeft = 0; phase = .caught; return }

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
            let rate = holding ? (Steal.awareRate[who] ?? 0.2) : -Steal.awareCalm
            let next = (aware[who] ?? 0) + CGFloat(dt * rate)

            if next >= 1 {
                aware[who] = 0          // they look away again, but the damage is done
                spotted()
                return
            }
            aware[who] = max(0, next)
        }
    }

    /// one full aware bar is one strike, never a trickle
    private func spotted() {
        suspicion += 1
        holding = false
        if suspicion >= Steal.strikes {
            phase = .caught
        } else {
            phase = .penalty
            penaltyLeft = Steal.penalty
        }
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
    let seat = Seating.seats(beside: .farLeft)[0]

    // you cant just hold it down. somebody clocks you before the bar fills.
    var greedy = StealViewModel(victim: .farLeft, thiefSeat: seat)
    greedy.holding = true
    while greedy.phase == .stealing { greedy.tick(1.0 / 60) }
    assert(greedy.suspicion == 1 && greedy.grab < 1, "one long hold has to get you spotted")

    // holding, easing off before anyone fills up, then holding again does land it
    var win = StealViewModel(victim: .farLeft, thiefSeat: seat)
    while !win.over && win.timeLeft > 1 {
        win.holding = (win.aware.values.max() ?? 0) < 0.55
        win.tick(1.0 / 60)
    }
    assert(win.phase == .succeeded, "easing off in time has to be a way to win")
    assert(win.suspicion == 0, "and it shouldnt cost a strike")

    // a full aware bar is exactly one strike, and it freezes you rather than ending it
    var s = StealViewModel(victim: .farLeft, thiefSeat: seat)
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
    var p = StealViewModel(victim: .near, thiefSeat: Seating.seats(beside: .near)[0])
    p.holding = true
    for _ in 0..<60 { p.tick(1.0 / 60) }
    let held = (p.grab, p.timeLeft, p.aware)
    p.pause()
    for _ in 0..<120 { p.tick(1.0 / 60) }
    assert(p.grab == held.0 && p.timeLeft == held.1 && p.aware == held.2, "pause freezes the lot")
    p.resume()
    assert(p.phase == .stealing)

    // three strikes and you're caught
    var c = StealViewModel(victim: .farRight, thiefSeat: seat)
    for _ in 0..<Steal.strikes {
        c.holding = true
        while c.phase == .stealing && !c.over { c.tick(1.0 / 60) }
        while c.phase == .penalty { c.tick(1.0 / 60) }
        while c.grab > 0 && !c.over { c.tick(1.0 / 60) }   // let it sag so the lift never lands
    }
    assert(c.suspicion == Steal.strikes && c.phase == .caught)

    // the clock running out ends it too
    var t = StealViewModel(victim: .near, thiefSeat: seat)
    while t.timeLeft > 0 { t.tick(1) }
    assert(t.phase == .caught)
    #endif
}
