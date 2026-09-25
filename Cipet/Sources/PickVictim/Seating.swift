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

    /// the seat beside, on the same bench, or nothing at the end of it
    static func right(of p: Person) -> Person? { neighbour(p, 1) }
    static func left(of p: Person) -> Person? { neighbour(p, -1) }
    private static func neighbour(_ p: Person, _ step: Int) -> Person? {
        guard let bench = benches.first(where: { $0.contains(p) }), let i = bench.firstIndex(of: p),
              bench.indices.contains(i + step) else { return nil }
        return bench[i + step]
    }

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

    /// where their bar hangs: centred over their head with a gap above it, whichever bench
    /// they're on. scaled down from the design's 68x20 so neighbours' bars never touch.
    static func awareSlot(_ p: Person) -> CGRect {
        let size = CGSize(width: Tut.awareBox.width * Tut.awareScale,
                          height: Tut.awareBox.height * Tut.awareScale)
        let head = p == .kid ? CGPoint(x: Tut.bocah.midX, y: Tut.bocah.minY + Tut.kidHeadDrop)
                             : CGPoint(x: spot(p).midX, y: spot(p).minY - Tut.headLift)
        return CGRect(x: head.x - size.width / 2, y: head.y - Tut.awareGap - size.height,
                      width: size.width, height: size.height)
    }

    /// which bench a thief's seat is on: 0 the far one, 1 the near one
    static func bench(of seat: CGRect) -> Int {
        benches[1].map(thiefSpot).contains(seat) ? 1 : 0
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
    // every bar sits over its own head, clear of it, and never touches a neighbour's
    let everyone = Seating.dealt + [.kid]
    for p in everyone {
        let bar = Seating.awareSlot(p)
        let head = p == .kid ? Tut.bocah.midX : Seating.spot(p).midX
        assert(abs(bar.midX - head) < 0.01, "\(p)'s bar is off their head")
        assert(bar.maxY < (p == .kid ? Tut.bocah.minY + Tut.kidHeadDrop : Seating.spot(p).minY - Tut.headLift),
               "\(p)'s bar sits on their head")
        for q in everyone where q != p {
            assert(!bar.intersects(Seating.awareSlot(q)), "\(p) and \(q)'s bars overlap")
        }
    }

    // only people on the benches can be robbed, and only into an empty seat
    assert(!fixed.targets.contains(.kid) && fixed.seats(beside: .kid).isEmpty)
    for v in fixed.targets {
        for seat in fixed.seats(beside: v) {
            assert(!fixed.targets.map(Seating.thiefSpot).contains(seat), "that seat's taken")
        }
    }
    // a full bench leaves nobody on it a seat
    let packed = Arrangement(cast: [.farLeft: Rider(who: "Music"), .farMid: Rider(who: "Sleepy"),
                                    .farRight: Rider(who: "LeftDuo")])
    assert(packed.seats(beside: .farMid).isEmpty && !packed.playable)

    // the drawings line up with the thief's seats and sit on their own bench
    for p in Seating.dealt {
        assert(abs(Seating.spot(p).midX - Seating.thiefSpot(p).midX) < 0.01, "\(p) is off its seat")
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
