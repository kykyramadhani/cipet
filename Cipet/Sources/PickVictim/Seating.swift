import SwiftUI

// who is sat where, which empty spots that leaves, and where their aware bar hangs.
// the driver is scenery. the kid on the fold-down seat by the door cant be robbed either,
// but he still watches you, so he still gets a bar.
enum Seating {
    enum Person: CaseIterable {
        case farLeft, farRight, near, kid
    }

    /// which way a seat's occupant is drawn, which is what decides who can sit there
    enum Facing { case front, back, fixed }

    static func facing(_ p: Person) -> Facing {
        switch p {
        case .farLeft, .farRight: return .front   // far bench, facing you
        case .near:               return .back    // near bench, seen from behind
        case .kid:                return .fixed   // the fold-down seat by the door
        }
    }

    /// the seats a new round is allowed to reshuffle. the driver isnt even in here, and the
    /// kid by the door is fixed art, so neither can ever be dealt.
    static let dealt: [Person] = [.farLeft, .farRight, .near]

    /// the ones you're allowed to pick
    static let victims: [Person] = [.farLeft, .farRight, .near]

    static func spot(_ p: Person) -> CGRect {
        switch p {
        case .farLeft:  return Tut.kiriB
        case .farRight: return Tut.kiriA
        case .near:     return Tut.kanan
        case .kid:      return Tut.bocah
        }
    }

    static func art(_ p: Person) -> String {
        switch p {
        case .farLeft:  return "tut_kiri_b"
        case .farRight: return "tut_kiri_a"
        case .near:     return "tut_kanan"
        case .kid:      return "tut_bocah"
        }
    }

    /// the same drawing in Yellow/50, for whoever is being watched
    static func hotArt(_ p: Person) -> String { art(p) + "_hot" }

    /// where the bar sits, measured off the design rather than derived — the sprites have
    /// uneven transparent margins so a formula puts them in the wrong place.
    static func awareSlot(_ p: Person) -> CGRect {
        let box = Tut.awareBox
        switch p {
        case .farLeft:  return CGRect(x:  35.15, y: 100, width: box.width, height: box.height)
        case .farRight: return CGRect(x: 158,    y: 100, width: box.width, height: box.height)
        case .near:     return CGRect(x: 101,    y: 192, width: box.width, height: box.height)
        case .kid:      return CGRect(x: 232,    y: 108, width: box.width, height: box.height)
        }
    }

    /// each bench left to right, nil meaning a spot the thief could take
    private static let benches: [[Person?]] = [[.farLeft, nil, .farRight],
                                               [nil, .near, nil]]
    private static let spots: [[CGRect]] = [[Tut.kiriB, Tut.seated, Tut.kiriA],
                                            [Tut.ghosts[0], Tut.kanan, Tut.ghosts[1]]]

    /// the empty seats either side of a victim. someone on the end of a bench only has one,
    /// someone in the middle has two, which is what decides how many spots you get offered.
    static func seats(beside victim: Person) -> [CGRect] {
        for (b, bench) in benches.enumerated() {
            guard let i = bench.firstIndex(of: victim) else { continue }
            return [i - 1, i + 1]
                .filter { bench.indices.contains($0) && bench[$0] == nil }
                .map { spots[b][$0] }
        }
        return []
    }

    /// everyone still minding their own business, which is everyone but the mark
    static func idle(besides victim: Person) -> [Person] {
        Person.allCases.filter { $0 != victim }
    }
}

func runSeatingChecks() {
    #if DEBUG
    assert(Seating.seats(beside: .farLeft).count == 1, "sat on the end, one seat beside them")
    assert(Seating.seats(beside: .farRight).count == 1)
    assert(Seating.seats(beside: .near).count == 2, "sat in the middle, two seats beside them")
    assert(Seating.seats(beside: .farLeft) == Seating.seats(beside: .farRight),
           "the far bench only has the one gap, whichever end you pick")

    assert(Seating.victims.count == 3, "three you can rob, the kid and the driver are off limits")
    assert(!Seating.victims.contains(.kid))
    for v in Seating.victims {
        assert(!Seating.seats(beside: v).isEmpty, "every victim has somewhere to sit next to them")
        assert(!Seating.seats(beside: v).contains(Seating.spot(v)))
    }

    // the kid has no seat beside him to take, which is why he isnt on the list
    assert(Seating.seats(beside: .kid).isEmpty)

    // everybody who isnt the mark gets a bar, kid included
    assert(Seating.idle(besides: .farLeft).count == 3)
    assert(Seating.idle(besides: .farLeft).contains(.kid))

    // the two fixed spots are out of the shuffle, everyone you can rob is in it
    assert(!Seating.dealt.contains(.kid), "the front door passenger never gets reshuffled")
    assert(Seating.dealt.sorted(by: { "\($0)" < "\($1)" })
        == Seating.victims.sorted(by: { "\($0)" < "\($1)" }), "you can rob every dealt seat")
    assert(Seating.facing(.near) == .back && Seating.facing(.farLeft) == .front)

    // the bars sit above their owner and dont land on top of each other
    for p in Seating.Person.allCases {
        let slot = Seating.awareSlot(p)
        assert(slot.maxY <= Seating.spot(p).midY, "\(p)'s bar should be over their head")
    }
    #endif
}
