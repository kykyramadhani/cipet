import SwiftUI

// what survives a round: which round we're on, whether the tutorial is done, and the takings.
// everything else is rebuilt from scratch each time, which is what makes Next Round a real
// new round rather than a rewind.
@Observable final class GameSession {
    private(set) var round = 1
    private(set) var takings = 0
    private(set) var arrangement = Arrangement.random(avoiding: nil)

    var tutorialPending = false

    func startFirstRound() {
        round = 1
        takings = 0
        tutorialPending = Seen.shouldShowTutorial
        arrangement = Arrangement.random(avoiding: nil)
    }

    /// a fresh round: new number, new seating, and the tutorial stays done
    func nextRound(banking value: Int) {
        round += 1
        takings += value
        arrangement = Arrangement.random(avoiding: arrangement)
    }

    func tutorialFinished() {
        tutorialPending = false
        Seen.tutorial = true
    }
}

// who is sitting in which of the four passenger spots this round. the spots themselves never
// move — they're where the seats are drawn — so a round is shuffled by dealing different
// people into them.
struct Arrangement: Equatable {
    /// spot -> which character is in it
    let cast: [Seating.Person: Passenger]

    enum Passenger: CaseIterable, Equatable {
        case plain, music
        /// only `music` has a full animation so far; the rest stay on the flat artwork
        var animated: Bool { self == .music }
    }

    func who(_ spot: Seating.Person) -> Passenger { cast[spot] ?? .plain }

    /// one animated passenger per round for now, dropped into a different spot each time.
    /// when more animated art lands, widen `pool`.
    static func random(avoiding previous: Arrangement?) -> Arrangement {
        let spots = Seating.Person.allCases
        for _ in 0..<12 {
            guard let lucky = spots.randomElement() else { break }
            var cast = Dictionary(uniqueKeysWithValues: spots.map { ($0, Passenger.plain) })
            cast[lucky] = .music
            let next = Arrangement(cast: cast)
            if next != previous { return next }
        }
        return Arrangement(cast: Dictionary(uniqueKeysWithValues: spots.map { ($0, .plain) }))
    }
}

func runSessionChecks() {
    #if DEBUG
    let s = GameSession()
    s.startFirstRound()
    assert(s.round == 1 && s.takings == 0)

    let first = s.arrangement
    s.tutorialFinished()
    s.nextRound(banking: 20)
    assert(s.round == 2, "Next Round has to count up")
    assert(s.takings == 20, "and keep what was already taken")
    assert(!s.tutorialPending, "the tutorial never comes back in a later round")
    assert(s.arrangement != first, "and the angkot has to be dealt again")

    // it keeps dealing something new round after round
    var seen = [s.arrangement]
    for _ in 0..<6 {
        s.nextRound(banking: 0)
        assert(s.arrangement != seen.last, "two rounds running with the same seating is a bug")
        seen.append(s.arrangement)
    }
    assert(Set(seen.map(\.animatedSpot)).count > 1, "the animated passenger has to move about")

    // whoever ends up where, the picking rules are untouched
    for a in seen {
        assert(a.cast.count == Seating.Person.allCases.count, "everybody gets dealt a seat")
        for v in Seating.victims {
            assert(!Seating.seats(beside: v).isEmpty)
        }
    }
    #endif
}

extension Arrangement {
    /// only used by the checks, to prove the animated one actually moves
    var animatedSpot: Seating.Person? { cast.first { $0.value.animated }?.key }
}
