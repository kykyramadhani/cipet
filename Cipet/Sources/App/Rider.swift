import SwiftUI

// everybody who can ride in the back. which seat a face fits is decided by which way it's
// drawn, so the pools are split that way and a round only ever draws from the right one.
enum Rider: CaseIterable, Hashable {
    // drawn facing the front, so you see their face. the far bench.
    case frontA, frontB, music, sleepy
    // drawn from behind. the near bench. no animated art for these yet.
    case backA
    // the kid on the fold-down seat, who never changes
    case kid

    var facing: Seating.Facing {
        switch self {
        case .frontA, .frontB, .music, .sleepy: return .front
        case .backA:                            return .back
        case .kid:                              return .fixed
        }
    }

    var art: String {
        switch self {
        case .frontA: return "tut_kiri_a"
        case .frontB: return "tut_kiri_b"
        case .backA:  return "tut_kanan"
        case .kid:    return "tut_bocah"
        case .music:  return Clips.galau.frame(0)
        case .sleepy: return Clips.sleepy.frame(0)
        }
    }

    /// the same drawing in Yellow/50. only the flat cast have one — the animated ones get a
    /// ring round them instead, so they keep their own frames.
    var hotArt: String? {
        switch self {
        case .frontA, .frontB, .backA, .kid: return art + "_hot"
        case .music, .sleepy:                return nil
        }
    }

    var clip: Clip? {
        switch self {
        case .music:  return Clips.galau
        case .sleepy: return Clips.sleepy
        default:      return nil
        }
    }

    var animated: Bool { clip != nil }

    /// only offer a face we actually shipped the art for. drop the missing frames into the
    /// catalog and that face joins the pool on its own, no code change.
    var installed: Bool { UIImage(named: art) != nil }

    static func pool(_ facing: Seating.Facing) -> [Rider] {
        allCases.filter { $0.facing == facing && $0.installed }
    }

    /// who sits here when nobody has been dealt — the tutorial's cast, straight off the design
    static func fixed(at spot: Seating.Person) -> Rider {
        switch spot {
        case .farLeft:  return .frontB
        case .farRight: return .frontA
        case .near:     return .backA
        case .kid:      return .kid
        }
    }
}

func runRiderChecks() {
    #if DEBUG
    // nobody is offered a seat their artwork doesnt face
    for f in [Seating.Facing.front, .back] {
        let pool = Rider.pool(f)
        assert(!pool.isEmpty, "\(f) seats have nobody to put in them")
        assert(pool.allSatisfy { $0.facing == f })
        assert(!pool.contains(.kid), "the kid is fixed art, he's never dealt")
    }
    assert(!Rider.pool(.back).contains { $0.animated },
           "music and sleepy face forwards, they cant sit on the near bench")

    // every face in a pool resolves to artwork that's really in the bundle
    for p in Rider.pool(.front) + Rider.pool(.back) {
        assert(UIImage(named: p.art) != nil, "\(p) has no artwork")
        if let clip = p.clip {
            assert(UIImage(named: clip.last) != nil, "\(p)'s clip is missing its last frame")
            assert(clip.loops, "an idling passenger has to loop")
        }
        assert(p.animated == (p.hotArt == nil), "flat cast swap to yellow, animated ones get a ring")
    }

    // the defaults are what the tutorial's scenes are drawn with
    for spot in Seating.Person.allCases {
        assert(Rider.fixed(at: spot).art == Seating.art(spot))
        assert(!Rider.fixed(at: spot).animated, "the tutorial cast never animates")
    }
    #endif
}
