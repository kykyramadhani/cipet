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

    var tutorialPending = false

    func startFirstRound() {
        round = 1
        takings = 0
        items = 0
        played = 0
        tutorialPending = Seen.shouldShowTutorial
        arrangement = .random(avoiding: nil)
    }

    /// a fresh round: new number, new seating, and the tutorial stays done
    func nextRound(after r: RoundResult) {
        bank(r)
        round += 1
        arrangement = .random(avoiding: arrangement)
    }

    func endGame(after r: RoundResult) { bank(r) }

    func tutorialFinished() {
        tutorialPending = false
        Seen.tutorial = true
    }

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

// who is sitting where this round. how many there are, which seats they're in, who they
// are and what mood the animated ones start in are all dealt fresh each round; only the
// driver and the kid never change, and neither is in here.
struct Arrangement: Equatable {
    /// seat -> who's in it. a seat that isnt here is empty.
    let cast: [Seating.Person: Rider]
    /// how each animated passenger starts: headphones on or off, asleep or awake
    var start: [Seating.Person: Mood] = [:]

    /// the tutorial's cast, straight off the design
    static let fixed = Arrangement(cast: [.farLeft: .frontB, .farRight: .frontA, .nearMid: .backA])

    /// a round has at least two to choose between and always leaves a seat free
    static let headcount = 2...5

    func who(_ seat: Seating.Person) -> Rider? { cast[seat] }

    /// anyone on a bench. the kid and the driver never are.
    var targets: [Seating.Person] { Seating.dealt.filter { cast[$0] != nil } }

    /// everyone who can catch you at it: every passenger, whoever you're robbing too, and the kid
    var watchers: [Seating.Person] { targets + [.kid] }

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
            let seats = Seating.dealt.shuffled().prefix(Int.random(in: headcount))
            var cast: [Seating.Person: Rider] = [:]
            var taken: Set<Rider> = []   // one of each animated face per angkot, no twins
            for seat in seats {
                let pool = Rider.pool(Seating.facing(seat)).filter { !($0.animated && taken.contains($0)) }
                guard let rider = pool.randomElement() else { continue }
                if rider.animated { taken.insert(rider) }
                cast[seat] = rider
            }
            let start = cast.filter(\.value.animated).mapValues { _ in Bool.random() ? Mood.calm : .alert }
            let next = Arrangement(cast: cast, start: start)
            if next != previous && next.playable { return next }
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

    s.tutorialFinished()
    s.nextRound(after: RoundResult(value: 20, time: 30))
    assert(Record.shared.hasAny, "finishing a round is what puts the record button up")
    assert(s.round == 2, "Next Round has to count up")
    assert(s.takings == 20 && s.items == 1, "and keep what was already taken")
    assert(!s.tutorialPending, "the tutorial never comes back in a later round")

    s.nextRound(after: RoundResult(value: 0, time: 90))
    assert(s.items == 1, "a round you came away empty from isnt an item")
    assert(s.avgTime == "0:40", "60 seconds over 3 rounds")

    // deal a lot of rounds and make sure everything that's meant to change does
    var seen = [s.arrangement]
    for _ in 0..<80 {
        s.nextRound(after: RoundResult(value: 0, time: 0))
        assert(s.arrangement != seen.last!, "two rounds running with the same seating is a bug")
        seen.append(s.arrangement)
    }
    assert(Set(seen.map(\.cast.count)).count >= 3, "the number of passengers has to vary")
    assert(Set(seen.map { Set($0.cast.keys) }).count > 10, "and which seats they're in")
    for seat in Seating.dealt {
        assert(seen.contains { $0.cast[seat] != nil } && seen.contains { $0.cast[seat] == nil },
               "\(seat) should be sat in some rounds and empty in others")
    }
    for face in [Rider.music, .sleepy] {
        let seats = Set(seen.flatMap { a in a.cast.filter { $0.value == face }.map(\.key) })
        assert(seats.count > 1, "\(face) is always in the same seat, or never dealt at all")
        let moods = Set(seen.flatMap { a in a.cast.filter { $0.value == face }.compactMap { a.start[$0.key] } })
        assert(moods == [.calm, .alert], "\(face) should start both ways round")
    }

    for a in seen {
        assert(Arrangement.headcount.contains(a.cast.count))
        assert(a.playable, "every round leaves someone you can sit next to")
        assert(a.cast[.kid] == nil, "the kid is fixed, he's never dealt")
        for (seat, rider) in a.cast {
            assert(rider.facing == Seating.facing(seat), "\(rider) is facing the wrong way for \(seat)")
        }
        let faces = a.cast.values.filter(\.animated)
        assert(faces.count == Set(faces).count, "no twins")
        assert(Set(a.start.keys) == Set(a.cast.filter(\.value.animated).keys),
               "only the animated ones have a mood")
    }
    assert(Arrangement.fixed.cast.count == 3 && Arrangement.fixed.start.isEmpty,
           "the tutorial cast comes straight off the design")
    #endif
}
