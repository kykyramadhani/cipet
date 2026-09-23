import SwiftUI

enum PState { case busy, waking, alert, shock }

struct Passenger {
    let kind: Kind
    var state: PState = .busy
    var timer: Double                // time left in the current state
    var rideLeft: Double             // time left before they get off
    var awareness: Double = 0
    var loot: Loot?

    init(_ kind: Kind) {
        self.kind = kind
        self.timer = Double.random(in: kind.config.busyTime)
        self.rideLeft = Double.random(in: Tune.rideTime)
        self.loot = Loot.allCases.randomElement()
    }

    var awareRate: Double {
        switch state {
        case .busy:   return kind.config.awareBusy
        case .waking: return (kind.config.awareBusy + kind.config.awareAlert) / 2
        default:      return kind.config.awareAlert
        }
    }

    mutating func advance() {
        let c = kind.config
        switch state {
        case .busy:   state = .waking; timer = c.wakeTime
        case .waking: state = .alert;  timer = Double.random(in: c.alertTime)
        case .alert:  state = .busy;   timer = Double.random(in: c.busyTime)
        case .shock:  timer = 99
        }
    }
}

enum Phase { case play, paused, win, caught }

struct Flash { var seat: Int; var text: String; var loot: String; var life: Double }

struct Game {
    var seats: [Passenger?] = []
    var thief = 0
    var facing = 1                        // -1 left, +1 right
    var slide  = 0.0
    var steals: [Int: Double] = [:]       // seat -> progress 0...1, more than one at once is fine
    var boardIn: [Int: Double] = [:]      // empty seat -> time left before somebody gets on
    var score  = 0
    var taken  = 0
    var time   = Tune.round
    var phase: Phase = .play
    var flash: Flash?
    var roadX = 0.0
    var clock = 0.0

    static func new() -> Game {
        var g = Game()
        g.seats = [Passenger?](repeating: nil, count: Layout.seats.count)
        g.thief = Int.random(in: 0..<3)                 // start on the far bench so we can see him

        // make sure theres somebody to rob right away
        if let n = Layout.seats.indices.filter({ Layout.adjacent($0, g.thief) }).randomElement() {
            g.seats[n] = Passenger(g.pick(for: n))
        }
        for i in g.freeSeats().shuffled().prefix(Tune.maxPassengers - 1) {
            g.seats[i] = Passenger(g.pick(for: i))
        }
        return g
    }

    var passengerCount: Int { seats.compactMap { $0 }.count }
    func freeSeats() -> [Int] { seats.indices.filter { seats[$0] == nil && $0 != thief } }

    /// any empty seat is fair game, near bench included
    func isEmpty(_ i: Int) -> Bool { seats.indices.contains(i) && seats[i] == nil && i != thief }
    func canMove(_ i: Int) -> Bool { phase == .play && isEmpty(i) }

    func canSteal(_ i: Int) -> Bool {
        guard phase == .play, Layout.adjacent(i, thief), let p = seats[i] else { return false }
        return p.loot != nil && p.state != .shock
    }

    var reachable: [Int] { seats.indices.filter { Layout.adjacent($0, thief) && seats[$0] != nil } }

    /// random, but never a twin of whoevers sitting next to them
    private func pick(for seat: Int) -> Kind {
        let taken = seats.indices.filter { Layout.adjacent($0, seat) }.compactMap { seats[$0]?.kind }
        let pool = Kind.allCases.filter { !taken.contains($0) }
        return pool.randomElement() ?? .sleeper
    }

    mutating func move(to i: Int) {
        guard canMove(i) else { return }
        facing = i > thief ? 1 : -1
        let old = thief
        thief = i
        slide = Tune.slideTime
        steals.removeAll()
        boardIn[i] = nil                                     // nobody gets the seat we just took
        if seats[old] == nil { boardIn[old] = Double.random(in: Tune.boardWait) }
        for n in seats.indices where Layout.adjacent(n, i) {
            if var p = seats[n], p.state == .alert {
                p.awareness = min(1, p.awareness + Tune.moveSuspicion)
                seats[n] = p
            }
        }
    }

    mutating func beginSteal(_ i: Int) {
        guard canSteal(i), steals[i] == nil else { return }
        steals[i] = 0
        facing = i > thief ? 1 : -1
    }

    mutating func endSteal(_ i: Int) { steals[i] = nil }

    mutating func restart() { self = .new() }

    mutating func togglePause() {
        switch phase {
        case .play:   phase = .paused; steals.removeAll()
        case .paused: phase = .play
        default:      break
        }
    }

    mutating func tick(_ dt: Double) {
        guard phase == .play else { return }
        clock += dt
        roadX += dt * Tune.roadSpeed
        slide = max(0, slide - dt)
        if var f = flash { f.life -= dt; flash = f.life > 0 ? f : nil }

        time -= dt
        if time <= 0 { time = 0; phase = .win; steals.removeAll(); return }

        turnover(dt)

        for i in seats.indices {
            guard var p = seats[i] else { continue }
            p.timer -= dt
            if p.timer <= 0 { p.advance() }
            if steals[i] != nil {
                p.awareness = min(1, p.awareness + dt * p.awareRate)
            } else {
                p.awareness = max(0, p.awareness - dt * Tune.awareDecay)
            }
            seats[i] = p
        }

        for i in steals.keys.sorted() {
            guard let progress = steals[i], var p = seats[i] else { steals[i] = nil; continue }

            if p.awareness >= 1 {                       // spotted, round over
                p.state = .shock; p.timer = 99
                seats[i] = p
                phase = .caught; steals.removeAll()
                return
            }

            let next = progress + dt / p.kind.config.stealTime
            if next >= 1 {                              // got it
                let loot = p.loot
                score += loot?.value ?? 0
                taken += 1
                p.loot = nil                            // nothing left on them but they stay put
                seats[i] = p
                flash = Flash(seat: i, text: "+\(loot?.value ?? 0)k",
                              loot: loot?.art ?? "wallet", life: 1.0)
                steals[i] = nil
            } else {
                steals[i] = next
            }
        }
    }

    /// people get off when their ride is up, robbed or not. the seat sits empty a moment
    /// and then somebody new gets on.
    private mutating func turnover(_ dt: Double) {
        for i in seats.indices {
            if var p = seats[i] {
                p.rideLeft -= dt
                if p.rideLeft <= 0 {
                    seats[i] = nil
                    steals[i] = nil
                    boardIn[i] = Double.random(in: Tune.boardWait)
                } else {
                    seats[i] = p
                }
            } else if i != thief {
                var wait = boardIn[i] ?? Double.random(in: Tune.boardWait)
                wait -= dt
                if wait <= 0 && passengerCount < Tune.maxPassengers {
                    seats[i] = Passenger(pick(for: i))
                    boardIn[i] = nil
                } else {
                    boardIn[i] = max(wait, 0)            // full? sit at 0 until a slot frees up
                }
            }
        }
    }
}

// runs on every launch in debug

func runGameChecks() {
    #if DEBUG
    var g = Game.new()
    assert(g.seats.count == 7, "3 far + 4 near")
    assert(g.seats[g.thief] == nil)
    assert(g.passengerCount <= Tune.maxPassengers)
    assert(!g.reachable.isEmpty, "a round has to open with somebody in reach")

    // the two benches cant reach each other
    assert(Layout.adjacent(0, 1) && Layout.adjacent(3, 4))
    assert(!Layout.adjacent(2, 3), "far and near are opposite sides")

    // he can move into any empty seat, near bench included
    var m = Game.new()
    if let taken = m.seats.indices.first(where: { m.seats[$0] != nil }) {
        let was = m.thief
        m.move(to: taken)
        assert(m.thief == was, "an occupied seat has to be refused")
    }
    if let empty = m.freeSeats().first(where: { Layout.seats[$0].bench == .near }) {
        m.move(to: empty)
        assert(m.thief == empty, "he has to be able to sit on the near bench")
    }

    // robbing two people at once
    var a = Game()
    a.seats = [Passenger?](repeating: nil, count: Layout.seats.count)
    a.thief = 4
    for i in [3, 5] {
        var p = Passenger(.sleeper)
        p.state = .busy; p.timer = 99; p.rideLeft = 99; p.awareness = 0; p.loot = .wallet
        a.seats[i] = p
    }
    assert(a.reachable.sorted() == [3, 5], "from a middle seat both neighbours are in reach")
    a.beginSteal(3); a.beginSteal(5)
    assert(a.steals.count == 2)
    for _ in 0..<600 where !a.steals.isEmpty { a.tick(1.0 / 60) }
    assert(a.taken == 2 && a.score == 100)
    assert(!a.canSteal(3), "you only get one go at each person")
    assert(a.seats[3] != nil, "a robbed passenger stays put until their ride is up")

    // getting off because the ride is up, not because of the robbery
    var t = Game()
    t.seats = [Passenger?](repeating: nil, count: Layout.seats.count)
    t.thief = 0
    var p = Passenger(.sleeper); p.rideLeft = 0.5; p.timer = 99
    t.seats[1] = p
    for i in t.seats.indices where i != 1 { t.boardIn[i] = 999 }   // freeze the rest, seat 1 is the one under test
    for _ in 0..<60 { t.tick(1.0 / 60) }
    assert(t.seats[1] == nil, "they get off even if nobody robbed them")
    for _ in 0..<Int(Tune.boardWait.upperBound * 60) + 120 { t.tick(1.0 / 60) }
    assert(t.seats[1] != nil, "somebody new gets on")

    // losing: awareness fills up first
    var b = Game.new()
    if let v = b.reachable.first {
        b.seats[v]!.state = .alert; b.seats[v]!.timer = 99; b.seats[v]!.rideLeft = 99
        b.seats[v]!.awareness = 0.99
        b.beginSteal(v)
        b.tick(1.0 / 60)
        assert(b.phase == .caught && b.seats[v]?.state == .shock)
        assert(b.steals.isEmpty)
    }

    // round runs out
    var c = Game.new(); c.time = 0.01
    c.tick(1.0 / 60)
    assert(c.phase == .win && c.time == 0)

    // pause stops the clock and everything else
    var z = Game.new()
    if let v = z.reachable.first { z.beginSteal(v) }
    z.togglePause()
    assert(z.phase == .paused && z.steals.isEmpty, "pausing cancels whatever was in progress")
    let frozen = (z.time, z.roadX, z.clock)
    for _ in 0..<120 { z.tick(1.0 / 60) }
    assert((z.time, z.roadX, z.clock) == frozen, "nothing moves while paused")
    z.togglePause()
    z.tick(1.0 / 60)
    assert(z.phase == .play && z.time < frozen.0)
    z.phase = .win
    z.togglePause()
    assert(z.phase == .win, "you cant pause the end screen")
    #endif
}
