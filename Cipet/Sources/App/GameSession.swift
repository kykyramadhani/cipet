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
    }
}

// who is sitting in which passenger spot this round. the spots never move — they're where
// the seats are drawn — so a round is shuffled by dealing a new face into each one.
struct Arrangement: Equatable {
    /// spot -> who's in it. anything missing falls back to the design's own cast.
    let cast: [Seating.Person: Rider]

    /// everybody on their default artwork. the tutorial uses this so its scenes always
    /// look the same as the design.
    static let fixed = Arrangement(cast: [:])

    func who(_ spot: Seating.Person) -> Rider { cast[spot] ?? .fixed(at: spot) }

    /// deal every reshufflable seat from the pool that matches which way it faces, then
    /// reject the draw if it came out the same as last round.
    static func random(avoiding previous: Arrangement?) -> Arrangement {
        for _ in 0..<20 {
            var cast: [Seating.Person: Rider] = [:]
            // one of each animated face per angkot, so you never get twins
            var taken: Set<Rider> = []

            for spot in Seating.dealt {
                let pool = Rider.pool(Seating.facing(spot)).filter {
                    !($0.animated && taken.contains($0))
                }
                let pick = pool.randomElement() ?? .fixed(at: spot)
                if pick.animated { taken.insert(pick) }
                cast[spot] = pick
            }

            let next = Arrangement(cast: cast)
            if next != previous { return next }
        }
        return .fixed
    }
}

func runSessionChecks() {
    #if DEBUG
    let s = GameSession()
    s.startFirstRound()
    assert(s.round == 1 && s.takings == 0 && s.items == 0)

    s.tutorialFinished()
    s.nextRound(after: RoundResult(value: 20, time: 30))
    assert(s.round == 2, "Next Round has to count up")
    assert(s.takings == 20 && s.items == 1, "and keep what was already taken")
    assert(!s.tutorialPending, "the tutorial never comes back in a later round")

    s.nextRound(after: RoundResult(value: 0, time: 90))
    assert(s.items == 1, "a round you came away empty from isnt an item")
    assert(s.avgTime == "0:40", "60 seconds over 3 rounds")

    // it keeps dealing something new round after round
    var seen = [s.arrangement]
    for _ in 0..<40 {
        s.nextRound(after: RoundResult(value: 0, time: 0))
        assert(s.arrangement != seen.last!, "two rounds running with the same seating is a bug")
        seen.append(s.arrangement)
    }

    // every seat with a choice has to actually move about, not just one of them shuffling
    // along. the near bench only has the one drawing so far, so it sits this check out.
    for spot in Seating.dealt where Rider.pool(Seating.facing(spot)).count > 1 {
        assert(Set(seen.map { $0.who(spot) }).count > 1, "\(spot) got the same face every round")
    }
    // and it shouldnt settle into an A-B-A-B flip either
    assert(Set(seen.map(\.cast)).count > 2, "the shuffle is only alternating between two")

    for a in seen {
        for (spot, p) in a.cast {
            assert(Seating.dealt.contains(spot), "\(spot) is fixed art, it cant be dealt")
            assert(p.facing == Seating.facing(spot), "\(p) is facing the wrong way for \(spot)")
        }
        assert(a.who(.kid) == .kid, "the front door passenger never changes")
        assert(!a.who(.near).animated, "the near bench has no animated art yet")
        assert(a.cast.values.filter(\.animated).count <= 1, "no twins")
        // whoever ends up where, the picking rules are untouched
        for v in Seating.victims { assert(!Seating.seats(beside: v).isEmpty) }
    }
    assert(Arrangement.fixed.cast.isEmpty, "the tutorial cast comes straight off the design")
    #endif
}
