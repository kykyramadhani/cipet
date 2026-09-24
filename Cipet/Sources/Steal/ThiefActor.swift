import SwiftUI

// the thief's animation, one beat at a time. each beat either loops until the game moves on
// or plays once and hands over, which is what keeps stand-up and getting-caught from being
// cut short by the screen changing underneath them.
struct ThiefActor: View {
    enum Beat: Equatable { case sitting, reaching, stealing, returning, caught, standing }

    let beat: Beat
    let seat: CGRect
    let reachingLeft: Bool
    let space: DesignSpace
    var paused = false
    let onFinish: (Beat) -> Void

    var body: some View {
        place(Tut.inAngkot(Clips.box(over: seat)), space) {
            FrameAnimation(clip: clip, paused: paused) { onFinish(beat) }
        }
    }

    private var clip: Clip {
        switch beat {
        // sitting still is the first frame of getting up, held
        case .sitting:   return Clip(name: Clips.standUp.name, frames: 1)
        case .reaching:  return Clips.sitToSteal(reachingLeft: reachingLeft)
        case .stealing:  return Clips.steal(reachingLeft: reachingLeft)
        case .returning: return Clips.stealToSit(reachingLeft: reachingLeft)
        case .caught:    return Clips.caughtMidSteal(reachingLeft: reachingLeft)
        case .standing:  return Clips.standUp
        }
    }
}

func runThiefChecks() {
    #if DEBUG
    // every beat resolves to frames that were actually installed
    for reach in [true, false] {
        let clips = [Clips.sitToSteal(reachingLeft: reach), Clips.steal(reachingLeft: reach),
                     Clips.stealToSit(reachingLeft: reach), Clips.caughtMidSteal(reachingLeft: reach)]
        for c in clips { assert(c.frames > 1, "\(c.name) needs more than one frame") }
    }
    // only the mid-action pose loops; everything else has to end so the next beat can start
    assert(Clips.steal(reachingLeft: true).loops && Clips.steal(reachingLeft: false).loops)
    assert(!Clips.standUp.loops && !Clips.caughtMidSteal(reachingLeft: false).loops)
    #endif
}
