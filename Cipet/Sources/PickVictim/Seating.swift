import SwiftUI

// where people can sit in the back and where everything about them is drawn. who is
// actually sat where changes every round and lives in Arrangement. the driver is scenery,
// and the kid on the fold-down seat by the door cant be robbed but does watch you.
enum Seating {
    /// three on the far bench facing you, three on the near one with their backs to you,
    /// and the kid's seat
    enum Person: CaseIterable, Hashable {
        case farLeft, farMid, farRight, nearLeft, nearMid, nearRight, kid
    }

    /// which way a seat's occupant is drawn, which is what decides who can sit there
    enum Facing { case front, back, fixed }

    /// each bench left to right. neighbours on a bench are who you can sit beside.
    static let benches: [[Person]] = [[.farLeft, .farMid, .farRight],
                                      [.nearLeft, .nearMid, .nearRight]]

    /// the seats a round deals passengers into. the kid is fixed, and the driver isnt back here.
    static let dealt = benches.flatMap { $0 }

    static func facing(_ p: Person) -> Facing {
        if p == .kid { return .fixed }
        return benches[0].contains(p) ? .front : .back
    }

    /// where a passenger's drawing goes. the far ends and the near middle are straight off
    /// the design; the rest are the same drawings centred over the thief's seat there.
    static func spot(_ p: Person) -> CGRect {
        switch p {
        case .farLeft:   return Tut.kiriB
        case .farRight:  return Tut.kiriA
        case .farMid:    return centred(Tut.kiriB.size, on: thiefSpot(p).midX, y: Tut.kiriB.minY)
        case .nearMid:   return Tut.kanan
        case .nearLeft, .nearRight:
            return centred(Tut.kanan.size, on: thiefSpot(p).midX, y: Tut.kanan.minY)
        case .kid:       return Tut.bocah
        }
    }

    /// where the thief is drawn when he sits there: the far middle and the near ends are off
    /// the design, the others line up under whoever normally sits in that seat
    static func thiefSpot(_ p: Person) -> CGRect {
        switch p {
        case .farMid:    return Tut.seated
        case .nearLeft:  return Tut.ghosts[0]
        case .nearRight: return Tut.ghosts[1]
        case .farLeft, .farRight:
            return centred(Tut.seated.size, on: spot(p).midX, y: Tut.seated.minY)
        case .nearMid:
            return centred(Tut.ghosts[0].size, on: spot(p).midX, y: Tut.ghosts[0].minY)
        case .kid:       return .zero
        }
    }

    /// where their bar hangs. the offsets from the drawing are measured off the design, the
    /// sprites have uneven transparent margins so centring them puts the bar in the wrong place.
    static func awareSlot(_ p: Person) -> CGRect {
        let box = Tut.awareBox, s = spot(p)
        switch facing(p) {
        case .front: return CGRect(x: s.minX - 8.5,  y: 100, width: box.width, height: box.height)
        case .back:  return CGRect(x: s.minX - 4.63, y: 192, width: box.width, height: box.height)
        case .fixed: return CGRect(x: 232,           y: 108, width: box.width, height: box.height)
        }
    }

    private static func centred(_ size: CGSize, on midX: CGFloat, y: CGFloat) -> CGRect {
        CGRect(x: midX - size.width / 2, y: y, width: size.width, height: size.height)
    }
}

func runSeatingChecks() {
    #if DEBUG
    // the design's own seats come out exactly where they were
    let fixed = Arrangement.fixed
    assert(fixed.seats(beside: .farLeft) == [Tut.seated] && fixed.seats(beside: .farRight) == [Tut.seated],
           "on the end of the far bench, the one gap is the middle")
    assert(fixed.seats(beside: .nearMid) == Tut.ghosts, "in the middle, both ends of the near bench")
    assert(Seating.awareSlot(.farLeft).minX == 35.15 && Seating.awareSlot(.farRight).minX == 158)
    assert(abs(Seating.awareSlot(.nearMid).minX - 101) < 0.001)

    // only people on the benches can be robbed, and only into an empty seat
    assert(!fixed.targets.contains(.kid) && fixed.seats(beside: .kid).isEmpty)
    for v in fixed.targets {
        for seat in fixed.seats(beside: v) {
            assert(!fixed.targets.map(Seating.thiefSpot).contains(seat), "that seat's taken")
        }
    }
    // a full bench leaves nobody on it a seat
    let packed = Arrangement(cast: [.farLeft: .frontA, .farMid: .frontB, .farRight: .frontA])
    assert(packed.seats(beside: .farMid).isEmpty && !packed.playable)

    // the drawings line up with the thief's seats and sit on their own bench
    for p in Seating.dealt {
        assert(abs(Seating.spot(p).midX - Seating.thiefSpot(p).midX) < 0.01, "\(p) is off its seat")
        assert(Seating.awareSlot(p).maxY <= Seating.spot(p).midY, "\(p)'s bar should be over their head")
        // nothing you can tap to pick a target reaches the driver, and barely the kid
        assert(!Seating.spot(p).intersects(Tut.sopir), "\(p) overlaps the driver")
        assert(!Seating.spot(p).insetBy(dx: 1, dy: 1).intersects(Tut.bocah), "\(p) overlaps the kid")
    }
    for bench in Seating.benches {
        for (a, b) in zip(bench, bench.dropFirst()) {
            assert(Seating.thiefSpot(a).midX < Seating.thiefSpot(b).midX, "the bench runs left to right")
        }
    }

    let pick = PickVictimViewModel(cast: fixed)
    pick.pick(.kid)
    assert(pick.target == nil && pick.stage == .target, "tapping the kid does nothing")

    // the tab hangs straight off the timer, centred under it, and each line of it is the
    // width the design has it at (centred text, so 138 and 170 wide)
    assert(Pick.tab.minY == Tut.clockPanel.maxY && Pick.tab.midX == Tut.clockPanel.midX)
    assert(abs(GlyphLine("Choose your target", size: Pick.tabSize).box.width - 138) < 1.5)
    assert(abs(GlyphLine("Confirm if you\u{2019}re ready!", size: Pick.tabSize).box.width - 170) < 1.5)
    assert(abs(GlyphLine("x", size: Pick.tabSize).box.height - Pick.tabText.height) < 0.01,
           "the text box is skranji's own line height")
    #endif
}
