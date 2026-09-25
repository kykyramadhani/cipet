import SwiftUI

// the thief's animation, one beat at a time. each beat either loops until the game moves on
// or plays once and hands over, which is what keeps stand-up and getting-caught from being
// cut short by the screen changing underneath them.
struct ThiefActor: View {
    /// `caught` runs twice over: once as the flinch during an almost-caught cooldown, and
    /// once for real before the cage comes down. `midSteal` picks which drawing of it.
    enum Beat: Equatable {
        case sitting, reaching, stealing, returning, standing
        case caught(midSteal: Bool)
    }

    let beat: Beat
    let seat: CGRect
    let reachingLeft: Bool
    /// sat on the near bench, back to us
    var behind = false
    let space: DesignSpace
    var paused = false
    let onFinish: (Beat) -> Void

    var body: some View {
        place(Tut.inAngkot(Clips.box(over: seat)), space) {
            FrameAnimation(clip: clip, paused: paused) { onFinish(beat) }
        }
    }

    private var clip: Clip {
        let move = { (m: String, loops: Bool) in
            Clips.thief(m, left: reachingLeft, behind: behind, loops: loops)
        }
        switch beat {
        // sitting still is the first frame of getting up, held
        case .sitting:
            return behind ? Clips.behindIdle(left: reachingLeft) : Clip(move("Idle-Standup", false).name, length: 1)
        case .reaching:  return move("Idle-Nyopet", false)
        case .stealing:  return move("Nyopet", true)
        case .returning: return move("Nyopet-Idle", false)
        case let .caught(mid): return move(mid ? "Nyopet-Caught" : "Caught", false)
        case .standing:  return move("Idle-Standup", false)
        }
    }
}

func runThiefChecks() {
    #if DEBUG
    // every move resolves to real frames from every seat, reaching either way
    for left in [true, false] {
        for behind in [true, false] {
            for m in ["Idle-Nyopet", "Nyopet", "Nyopet-Idle", "Nyopet-Caught", "Caught", "Idle-Standup"] {
                // from behind, a move not drawn yet is one held frame of him sat with his back to us
                assert(Clips.thief(m, left: left, behind: behind).frames >= (behind ? 1 : 2), "\(m) has no frames")
            }
        }
    }
    // from behind nothing ever resolves to a front-facing drawing
    for left in [true, false] {
        for m in ["Idle-Nyopet", "Nyopet", "Nyopet-Idle", "Nyopet-Caught", "Caught", "Idle-Standup"] {
            assert(Clips.thief(m, left: left, behind: true).name.contains("Behind"), "\(m) turned him round")
        }
        assert(Clips.behindIdle(left: left).name.contains("Behind"))
    }
    // the new drawings are the ones used: the redrawn left set, and his back on the near bench
    assert(Clips.thief("Idle-Nyopet", left: true, behind: false).name == "LeftCipetIdle-Nyopet")
    assert(Clips.thief("Nyopet", left: false, behind: true).name == "BehindCipetNyopet")
    assert(Clips.thief("Nyopet", left: true, behind: true).name == "LeftBehindCipetNyopet")
    #endif
}
