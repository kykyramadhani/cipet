import SwiftUI

/// what one round was worth once it's over
struct RoundResult {
    let value: Int      // thousands of rupiah, 0 if he came away with nothing
    let time: Double    // seconds the round actually took
}

// what survives a round: which round we're on, whether the tutorial is done, and the takings.
// everything else is rebuilt from scratch each time, which is what makes Next Round a real
// new round rather than a rewind.
@Observable final class GameSession {
    private(set) var round = 1
    private(set) var takings = 0
    private(set) var items = 0
    private(set) var played = 0.0
    private(set) var arrangement = Arrangement.fixed

    func startFirstRound() {
        round = 1
        takings = 0
        items = 0
        played = 0
        arrangement = .random(avoiding: nil)
    }

    /// a fresh round: new number, new seating, and the tutorial stays done
    func nextRound(after r: RoundResult) {
        bank(r)
        round += 1
        arrangement = .random(avoiding: arrangement)
    }

    func endGame(after r: RoundResult) { bank(r) }

    /// how long a round took on average, over the ones actually played
    var avgTime: String { mmss(played / Double(max(1, round))) }

    private func bank(_ r: RoundResult) {
        takings += r.value
        if r.value > 0 { items += 1 }
        played += r.time
        // banking is the moment a round is genuinely over, whether the run carries on or
        // stops here — so it's the moment the record can move
        Record.shared.note(round: round, takings: takings)
    }
}

// how one passenger behaves this round, dealt fresh every round and fixed until it ends.
// the four rates are always in this order, whatever gets rolled:
//   grabRate < slip < awareCalm < awareRate
// so the steal bar is the sluggish one and suspicion the twitchy one, for everyone.
struct Traits: Equatable {
    let grabRate: Double    // the steal bar fills this fast while you hold (they're the mark)
    let slip: Double        // and sags this fast when you let go
    let awareCalm: Double   // their bar drains this fast whenever they're not catching you
    let awareRate: Double   // and fills this fast while they're idle and you're at it
    /// how far their bar has to get before they clock you. their bar is drawn against this,
    /// so it still reads full at the moment of the strike.
    let threshold: CGFloat
    /// how long they stay idle, and how long in their own thing, before switching
    let idleFor: ClosedRange<Double>
    let calmFor: ClosedRange<Double>

    /// how watchful each kind of person is when idle, per second. the kid is by far the
    /// slowest: he's still watching, it just takes him a good while to get suspicious.
    static let watchful: [String: ClosedRange<Double>] = [
        "Sleepy": 0.26...0.34, "Music": 0.30...0.40, "Duo": 0.32...0.42, "Boy": 0.10...0.14,
    ]
    /// how long they drift off for. sleep lasts, a chat or a song less so.
    static let drift: [String: ClosedRange<Double>] = [
        "Sleepy": 6...11, "Music": 4...8, "Duo": 3...7,
    ]

    static func random(for rider: Rider) -> Traits {
        let key = watchful.keys.first { rider.person.contains($0) }
        let rate = Double.random(in: key.map { watchful[$0]! } ?? 0.30...0.40)
        // each one a slice below the next, so the order can never come out wrong
        let calm = rate * .random(in: 0.6...0.85)
        let slip = calm * .random(in: 0.6...0.85)
        let grab = slip * .random(in: 0.6...0.85)
        let away = drift.first { rider.person.contains($0.key) }?.value ?? 4...8
        return Traits(grabRate: grab, slip: slip, awareCalm: calm, awareRate: rate,
                      threshold: .random(in: 0.75...1), idleFor: 3...6, calmFor: away)
    }

    /// middling numbers and nobody ever drifting off, for the tutorial cast and the checks
    static let steady = Traits(grabRate: 0.143, slip: 0.16, awareCalm: 0.18, awareRate: 0.22,
                               threshold: 1, idleFor: 1_000_000...1_000_000, calmFor: 4...8)
}

// who is sitting where this round: how many, which seats, who they are, what they're
// doing to begin with, how watchful they are, and whether the kid is on at all. all of it
// is dealt fresh each round and holds still until the round is over. the driver never changes.
struct Arrangement: Equatable {
    /// seat -> who's in it. a seat that isnt here is empty.
    let cast: [Seating.Person: Rider]
    /// how each passenger starts: idle, or in their own thing
    var start: [Seating.Person: Mood] = [:]
    /// the kid rides some rounds and not others. when he's on he's always idle.
    var kid = true
    var traits: [Seating.Person: Traits] = [:]

    /// the tutorial's seats, straight off the design
    static let fixed = Arrangement(
        cast: [.farLeft: Rider(who: "Music"), .farRight: Rider(who: "Sleepy"),
               .nearMid: Rider(who: "BehindMusic")],
        start: [.farLeft: .alert, .farRight: .alert, .nearMid: .alert, .kid: .alert],
        traits: [.farLeft: .steady, .farRight: .steady, .nearMid: .steady, .kid: .steady])

    /// a round has at least two to choose between and always leaves a seat free
    static let headcount = 2...5

    func who(_ seat: Seating.Person) -> Rider? { seat == .kid ? (kid ? .kid : nil) : cast[seat] }

    /// anyone on a bench. the kid and the driver never are.
    var targets: [Seating.Person] { Seating.dealt.filter { cast[$0] != nil } }

    /// everyone who can catch you at it: every passenger, whoever you're robbing too, and the kid
    var watchers: [Seating.Person] { targets + (kid ? [.kid] : []) }

    func traits(_ p: Seating.Person) -> Traits { traits[p] ?? .steady }

    /// the empty seats either side of someone on their bench. the ends of a bench only have
    /// one neighbour, and a neighbour who's already sat there isnt a seat.
    func seats(beside p: Seating.Person) -> [CGRect] {
        guard let bench = Seating.benches.first(where: { $0.contains(p) }),
              let i = bench.firstIndex(of: p) else { return [] }
        return [i - 1, i + 1]
            .filter { bench.indices.contains($0) && cast[bench[$0]] == nil }
            .map { Seating.thiefSpot(bench[$0]) }
    }

    /// somebody has somewhere to sit next to them, or there's no round to play
    var playable: Bool { targets.contains { !seats(beside: $0).isEmpty } }

    static func random(avoiding previous: Arrangement?) -> Arrangement {
        for _ in 0..<50 {
            var cast: [Seating.Person: Rider] = [:]
            var dealt: Set<String> = []   // nobody twice, not even once from each side
            for seat in Seating.dealt.shuffled().prefix(Int.random(in: headcount)) where cast[seat] == nil {
                // a duo's right half needs the seat on their right, on the same bench
                let right = Seating.right(of: seat).flatMap { cast[$0] == nil ? $0 : nil }
                let pool = Rider.pool(Seating.facing(seat))
                    .filter { !dealt.contains($0.person) && ($0.partner == nil || right != nil) }
                guard let rider = pool.randomElement() else { continue }
                cast[seat] = rider
                dealt.insert(rider.person)
                if let half = rider.partner, let right { cast[right] = half; dealt.insert(half.person) }
            }
            var start = cast.mapValues { _ in Bool.random() ? Mood.calm : .alert }
            // a duo is one conversation, so both halves start together
            for (seat, rider) in cast where rider.isRightHalf {
                if let left = Seating.left(of: seat) { start[seat] = start[left] }
            }
            let kid = Bool.random()
            if kid { start[.kid] = .alert }
            var traits = cast.mapValues { Traits.random(for: $0) }
            if kid { traits[.kid] = .random(for: .kid) }
            let next = Arrangement(cast: cast, start: start, kid: kid, traits: traits)
            if next.cast != previous?.cast && headcount.contains(cast.count) && next.playable {
                return next
            }
        }
        return .fixed
    }
}

func runSessionChecks() {
    #if DEBUG
    // these play out dozens of rounds, and banking a round is what moves the record —
    // so put the player's own back the way it was on the way out
    let keptRound = Record.shared.highestRound, keptValue = Record.shared.topValue
    defer { Record.shared.restore(round: keptRound, value: keptValue) }

    let s = GameSession()
    s.startFirstRound()
    assert(s.round == 1 && s.takings == 0 && s.items == 0)

    s.nextRound(after: RoundResult(value: 20, time: 30))
    assert(Record.shared.hasAny, "finishing a round is what puts the record button up")
    assert(s.round == 2, "Next Round has to count up")
    assert(s.takings == 20 && s.items == 1, "and keep what was already taken")

    s.nextRound(after: RoundResult(value: 0, time: 90))
    assert(s.items == 1, "a round you came away empty from isnt an item")
    assert(s.avgTime == "0:40", "60 seconds over 3 rounds")

    // deal a lot of rounds and make sure everything that's meant to change does
    var seen = [s.arrangement]
    for _ in 0..<120 {
        s.nextRound(after: RoundResult(value: 0, time: 0))
        assert(s.arrangement.cast != seen.last!.cast, "two rounds running with the same seating is a bug")
        seen.append(s.arrangement)
    }
    assert(Set(seen.map(\.cast.count)).count >= 3, "the number of passengers has to vary")
    assert(Set(seen.map { Set($0.cast.keys) }).count > 10, "and which seats they're in")
    for seat in Seating.dealt {
        assert(seen.contains { $0.cast[seat] != nil } && seen.contains { $0.cast[seat] == nil },
               "\(seat) should be sat in some rounds and empty in others")
    }
    assert(seen.contains { $0.kid } && seen.contains { !$0.kid }, "the kid rides some rounds and not others")
    let everyone = Set(seen.flatMap { $0.cast.values })
    assert(everyone == Set(Rider.all), "every character in the catalog gets dealt, and only them")
    for rider in Rider.all where !rider.isRightHalf {
        let moods = Set(seen.flatMap { a in a.cast.filter { $0.value == rider }.compactMap { a.start[$0.key] } })
        assert(moods == [.calm, .alert], "\(rider.who) should start both ways round")
    }

    for a in seen {
        assert(Arrangement.headcount.contains(a.cast.count))
        assert(a.playable, "every round leaves someone you can sit next to")
        assert(a.cast[.kid] == nil, "the kid has his own seat, he's never dealt onto a bench")
        assert(a.watchers.contains(.kid) == a.kid && (a.start[.kid] != nil) == a.kid)
        if a.kid { assert(a.start[.kid] == .alert, "the kid is always idle") }
        for (seat, rider) in a.cast {
            assert(rider.facing == Seating.facing(seat), "\(rider.who) is facing the wrong way for \(seat)")
            // a duo sits as a pair, left half then right, on one bench, doing the same thing
            if let half = rider.partner {
                let right = Seating.right(of: seat)
                assert(right != nil && a.cast[right!] == half, "\(rider.who) is sat without their other half")
                assert(a.start[right!] == a.start[seat])
            }
            if rider.isRightHalf {
                assert(Seating.left(of: seat).flatMap { a.cast[$0] }?.partner == rider)
            }
        }
        let people = a.cast.values.map(\.person)
        assert(people.count == Set(people).count, "nobody twice in one angkot")
        assert(Set(a.start.keys) == Set(a.watchers) && Set(a.traits.keys) == Set(a.watchers))
        // the four rates keep their order for every single passenger dealt
        for t in a.traits.values {
            assert(t.grabRate < t.slip && t.slip < t.awareCalm && t.awareCalm < t.awareRate,
                   "grabRate < slip < awareCalm < awareRate, always")
            assert(t.threshold > 0 && t.threshold <= 1)
        }
    }
    // the kid, when he's on, catches on far slower than any passenger
    if let k = seen.first(where: \.kid), let rate = k.traits[.kid]?.awareRate {
        assert(rate <= Traits.watchful["Boy"]!.upperBound)
        let slowest = Traits.watchful.filter { $0.key != "Boy" }.map(\.value.lowerBound).min()!
        assert(Traits.watchful["Boy"]!.upperBound * 1.5 < slowest, "the kid has to be a lot slower")
    }
    #endif
}
