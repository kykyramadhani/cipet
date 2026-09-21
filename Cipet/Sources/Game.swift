import SwiftUI

// MARK: - Penumpang

enum PState { case busy, waking, alert, shock }

struct Passenger {
    let kind: Kind
    var state: PState = .busy
    var timer: Double                // sisa waktu di state sekarang
    var rideLeft: Double             // sisa waktu sebelum turun dari angkot
    var awareness: Double = 0
    var loot: Loot?

    init(_ kind: Kind) {
        self.kind = kind
        self.timer = Double.random(in: kind.config.busyTime)
        self.rideLeft = Double.random(in: Tune.rideTime)
        self.loot = Loot.allCases.randomElement()
    }

    func art(_ bench: Bench) -> String { kind.art(state, bench: bench) }

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

// MARK: - Ronde

enum Phase { case play, paused, win, caught }

struct Flash { var seat: Int; var text: String; var loot: String; var life: Double }

struct Game {
    var seats: [Passenger?] = []
    var copet = 0
    var facing = 1                        // -1 kiri, +1 kanan
    var slide  = 0.0
    var steals: [Int: Double] = [:]       // kursi -> progress 0...1, bisa lebih dari satu sekaligus
    var boardIn: [Int: Double] = [:]      // kursi kosong -> sisa waktu sebelum ada yang naik
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
        g.copet = Int.random(in: 0..<5)                 // mulai di bangku seberang, art-nya paling lengkap

        // pastikan ada satu tetangga yang bisa langsung dicopet
        if let n = Layout.seats.indices.filter({ Layout.adjacent($0, g.copet) }).randomElement() {
            g.seats[n] = Passenger(g.pick(for: n))
        }
        for i in g.freeSeats().shuffled().prefix(Tune.maxPassengers - 1) {
            g.seats[i] = Passenger(g.pick(for: i))
        }
        return g
    }

    // MARK: Aturan

    var passengerCount: Int { seats.compactMap { $0 }.count }
    func freeSeats() -> [Int] { seats.indices.filter { seats[$0] == nil && $0 != copet } }

    /// Kursi kosong mana pun boleh diduduki copet — termasuk bangku dekat.
    func isEmpty(_ i: Int) -> Bool { seats.indices.contains(i) && seats[i] == nil && i != copet }
    func canMove(_ i: Int) -> Bool { phase == .play && isEmpty(i) }

    func canSteal(_ i: Int) -> Bool {
        guard phase == .play, Layout.adjacent(i, copet), let p = seats[i] else { return false }
        return p.loot != nil && p.state != .shock
    }

    var reachable: [Int] { seats.indices.filter { Layout.adjacent($0, copet) && seats[$0] != nil } }

    /// Penumpang baru: acak, tapi hindari kembar sama tetangganya. Bangku dekat butuh art tampak belakang.
    private func pick(for seat: Int) -> Kind {
        let taken = seats.indices.filter { Layout.adjacent($0, seat) }.compactMap { seats[$0]?.kind }
        let pool = Kind.allCases.filter {
            (Layout.seats[seat].bench == .far || $0.hasBackArt) && !taken.contains($0)
        }
        return pool.randomElement() ?? .sleepy
    }

    // MARK: Aksi

    mutating func move(to i: Int) {
        guard canMove(i) else { return }
        facing = i > copet ? 1 : -1
        let old = copet
        copet = i
        slide = Tune.slideTime
        steals.removeAll()
        boardIn[i] = nil                                     // kursi yang baru diduduki nggak diisi orang
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
        facing = i > copet ? 1 : -1
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

    // MARK: Loop

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

            if p.awareness >= 1 {                       // ketahuan -> ronde selesai
                p.state = .shock; p.timer = 99
                seats[i] = p
                phase = .caught; steals.removeAll()
                return
            }

            let next = progress + dt / p.kind.config.stealTime
            if next >= 1 {                              // berhasil
                let loot = p.loot
                score += loot?.value ?? 0
                taken += 1
                p.loot = nil                            // barangnya habis, tapi orangnya tetap duduk
                seats[i] = p
                flash = Flash(seat: i, text: "+\(loot?.value ?? 0)k",
                              loot: loot?.art ?? "wallet", life: 1.0)
                steals[i] = nil
            } else {
                steals[i] = next
            }
        }
    }

    /// Penumpang turun kalau waktunya habis — kecopetan atau enggak, sama aja.
    /// Kursi yang ditinggal nganggur sebentar, terus ada penumpang baru naik.
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
            } else if i != copet {
                var wait = boardIn[i] ?? Double.random(in: Tune.boardWait)
                wait -= dt
                if wait <= 0 && passengerCount < Tune.maxPassengers {
                    seats[i] = Passenger(pick(for: i))
                    boardIn[i] = nil
                } else {
                    boardIn[i] = max(wait, 0)            // penuh? nunggu di 0 sampai ada slot
                }
            }
        }
    }
}

// MARK: - Self check (jalan tiap app dibuka di DEBUG)

func runGameChecks() {
    #if DEBUG
    var g = Game.new()
    assert(g.seats.count == 9, "5 kursi bangku seberang + 4 kursi bangku dekat")
    assert(g.seats[g.copet] == nil)
    assert(g.passengerCount <= Tune.maxPassengers)
    assert(!g.reachable.isEmpty, "mulai ronde harus ada yang bisa langsung dicopet")

    // bangku dekat cuma boleh diisi penumpang yang punya art tampak belakang
    for i in g.seats.indices where Layout.seats[i].bench == .near {
        if let k = g.seats[i]?.kind { assert(k.hasBackArt, "duo nggak punya art tampak belakang") }
    }

    // beda bangku nggak saling jangkau
    assert(Layout.adjacent(0, 1) && Layout.adjacent(5, 6))
    assert(!Layout.adjacent(4, 5), "kursi lipat dan bangku dekat beda sisi")

    // copet boleh pindah ke kursi kosong mana pun, termasuk bangku dekat
    var m = Game.new()
    if let far = m.seats.indices.first(where: { m.seats[$0] != nil }) {
        let was = m.copet
        m.move(to: far)
        assert(m.copet == was, "kursi terisi harus ditolak")
    }
    if let empty = m.freeSeats().first(where: { Layout.seats[$0].bench == .near }) {
        m.move(to: empty)
        assert(m.copet == empty, "copet harus bisa duduk di bangku dekat")
    }

    // nyopet dua orang barengan
    var a = Game()
    a.seats = [Passenger?](repeating: nil, count: Layout.seats.count)
    a.copet = 2
    for i in [1, 3] {
        var p = Passenger(.sleepy)
        p.state = .busy; p.timer = 99; p.rideLeft = 99; p.awareness = 0; p.loot = .wallet
        a.seats[i] = p
    }
    assert(a.reachable.sorted() == [1, 3], "dari kursi tengah harus nyampe dua-duanya")
    a.beginSteal(1); a.beginSteal(3)
    assert(a.steals.count == 2)
    for _ in 0..<600 where !a.steals.isEmpty { a.tick(1.0 / 60) }
    assert(a.taken == 2 && a.score == 100)
    assert(!a.canSteal(1), "barang cuma bisa diambil sekali")
    assert(a.seats[1] != nil, "yang udah dicopet tetap duduk sampai waktunya turun")

    // turun karena waktunya habis, bukan karena dicopet
    var t = Game()
    t.seats = [Passenger?](repeating: nil, count: Layout.seats.count)
    t.copet = 0
    var p = Passenger(.sleepy); p.rideLeft = 0.5; p.timer = 99
    t.seats[1] = p
    for i in t.seats.indices where i != 1 { t.boardIn[i] = 999 }   // kunci kursi lain biar yang diuji cuma kursi 1
    for _ in 0..<60 { t.tick(1.0 / 60) }
    assert(t.seats[1] == nil, "penumpang harus turun walau belum dicopet")
    for _ in 0..<Int(Tune.boardWait.upperBound * 60) + 120 { t.tick(1.0 / 60) }
    assert(t.seats[1] != nil, "harus ada penumpang baru yang naik")

    // gagal: awareness penuh duluan
    var b = Game.new()
    if let v = b.reachable.first {
        b.seats[v]!.state = .alert; b.seats[v]!.timer = 99; b.seats[v]!.rideLeft = 99
        b.seats[v]!.awareness = 0.99
        b.beginSteal(v)
        b.tick(1.0 / 60)
        assert(b.phase == .caught && b.seats[v]?.state == .shock)
        assert(b.steals.isEmpty)
    }

    // ronde habis
    var c = Game.new(); c.time = 0.01
    c.tick(1.0 / 60)
    assert(c.phase == .win && c.time == 0)

    // pause: waktu dan semua gerakan berhenti
    var z = Game.new()
    if let v = z.reachable.first { z.beginSteal(v) }
    z.togglePause()
    assert(z.phase == .paused && z.steals.isEmpty, "pause harus batalin percobaan yang lagi jalan")
    let frozen = (z.time, z.roadX, z.clock)
    for _ in 0..<120 { z.tick(1.0 / 60) }
    assert((z.time, z.roadX, z.clock) == frozen, "pas pause nggak boleh ada yang jalan")
    z.togglePause()
    z.tick(1.0 / 60)
    assert(z.phase == .play && z.time < frozen.0)
    z.phase = .win
    z.togglePause()
    assert(z.phase == .win, "layar akhir nggak bisa di-pause")
    #endif
}
