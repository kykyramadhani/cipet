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
// the seats are drawn — so a round is shuffled by dealing different people into them.
struct Arrangement: Equatable {
    /// spot -> who's in it. anything missing is the plain artwork.
    let cast: [Seating.Person: Passenger]

    enum Passenger: CaseIterable, Equatable {
        case plain, music
        /// only music has a full animation so far; the rest stay on the flat artwork
        var animated: Bool { self == .music }
    }

    /// nobody animated. the tutorial uses this so its scenes always look the same.
    static let fixed = Arrangement(cast: [:])

    func who(_ spot: Seating.Person) -> Passenger { cast[spot] ?? .plain }

    /// music and sleepy are drawn facing forward, so they only fit the upper bench. the
    /// driver and the kid by the door are fixed art and never get dealt at all.
    static let dealt: [Seating.Person] = [.farLeft, .farRight]

    /// at most one animated passenger a round, in a different seat to last time
    static func random(avoiding previous: Arrangement?) -> Arrangement {
        let options = dealt.map { Arrangement(cast: [$0: .music]) } + [.fixed]
        return options.filter { $0 != previous }.randomElement() ?? .fixed
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
    for _ in 0..<8 {
        s.nextRound(after: RoundResult(value: 0, time: 0))
        assert(s.arrangement != seen.last!, "two rounds running with the same seating is a bug")
        seen.append(s.arrangement)
    }
    assert(Set(seen.map(\.animatedSpot)).count > 1, "the animated passenger has to move about")

    // the fixed pair are never dealt, and the animated art never lands on a lower seat
    for a in seen {
        for spot in a.cast.keys {
            assert(Arrangement.dealt.contains(spot), "\(spot) is fixed art, it cant be dealt")
        }
        assert(!a.who(.kid).animated && !a.who(.near).animated,
               "music/sleepy face forwards, they dont belong on the lower seats")
        // whoever ends up where, the picking rules are untouched
        for v in Seating.victims { assert(!Seating.seats(beside: v).isEmpty) }
    }
    assert(Arrangement.fixed.cast.isEmpty, "the tutorial cast is plain all the way through")
    #endif
}

extension Arrangement {
    /// only used by the checks, to prove the animated one actually moves
    var animatedSpot: Seating.Person? { cast.first { $0.value.animated }?.key }
}
