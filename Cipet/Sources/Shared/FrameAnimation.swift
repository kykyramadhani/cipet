import SwiftUI

// the animated art comes as numbered png sequences, all 300x300 with the character padded
// the same way, so every frame of every clip can be drawn on one rect and stay registered.
struct Clip: Equatable {
    let name: String
    let frames: Int
    var fps: Double = 24
    var loops = false
    /// played backwards. a few transitions only exist one way round and the reverse is the
    /// other half of the move, so this saves shipping the same drawings twice.
    var reversed = false

    var duration: Double { Double(frames) / fps }

    func frame(_ i: Int) -> String {
        let n = min(max(0, i), frames - 1)
        return String(format: "%@-%04d", name, reversed ? frames - 1 - n : n)
    }

    var last: String { frame(frames - 1) }
}

/// the whole cast, at their native 300x300 with the same padding
enum Clips {
    static let size = CGSize(width: 300, height: 300)

    // where the drawn character sits inside that 300x300, measured off the frames. the flat
    // artwork is cropped tight, so a clip has to be scaled and nudged to land on the same spot.
    private static let ink = CGRect(x: 64, y: 39, width: 173, height: 220)

    /// the rect to draw a clip in so its character lands on the flat sprite's box
    static func box(over spot: CGRect) -> CGRect {
        let k = spot.height / ink.height
        return CGRect(x: spot.minX - ink.minX * k, y: spot.minY - ink.minY * k,
                      width: size.width * k, height: size.height * k)
    }

    // the thief, reaching right
    static let sitToSteal  = Clip(name: "CipetIdle-Nyopet", frames: 24)
    static let stealing    = Clip(name: "CipetNyopet", frames: 12, loops: true)
    static let stealToSit  = Clip(name: "CipetNyopet-Idle", frames: 21)
    static let caughtMidSteal = Clip(name: "CipetNyopet-Caught", frames: 12)
    static let caughtSitting  = Clip(name: "CipetCaught", frames: 12)
    static let standUp     = Clip(name: "CipetIdle-Standup", frames: 13)

    // reaching left. there's no left "sit to steal", so the return trip runs backwards.
    static let sitToStealL = Clip(name: "LeftCipetNyopet-Idle", frames: 21, reversed: true)
    static let stealingL   = Clip(name: "LeftCipetNyopet", frames: 12, loops: true)
    static let stealToSitL = Clip(name: "LeftCipetNyopet-Idle", frames: 21)
    static let caughtMidStealL = Clip(name: "LeftCipetNyopet-Caught", frames: 12)

    // the passenger with the headphones
    static let musicToGalau = Clip(name: "MusicIdle-Galau", frames: 36)
    static let galau        = Clip(name: "MusicGalau", frames: 15, loops: true)
    static let galauToMusic = Clip(name: "MusicGalau-Idle", frames: 36)
    static let musicToAngry = Clip(name: "MusicIdle-Angry", frames: 18)
    static let galauToAngry = Clip(name: "MusicGalau-Marah", frames: 18)

    static func steal(reachingLeft: Bool) -> Clip { reachingLeft ? stealingL : stealing }
    static func sitToSteal(reachingLeft: Bool) -> Clip { reachingLeft ? sitToStealL : sitToSteal }
    static func stealToSit(reachingLeft: Bool) -> Clip { reachingLeft ? stealToSitL : stealToSit }
    static func caughtMidSteal(reachingLeft: Bool) -> Clip {
        reachingLeft ? caughtMidStealL : caughtMidSteal
    }
}

// plays a clip. a looping clip runs until it's swapped out; a one-shot holds on its last
// frame and calls `onFinish`, which is what lets one beat hand over to the next.
struct FrameAnimation: View {
    let clip: Clip
    var paused = false
    var onFinish: (() -> Void)?

    @State private var index = 0
    @State private var ticker: Timer?

    var body: some View {
        Image(clip.frame(index))
            .resizable()
            .onAppear { restart() }
            .onDisappear { stop() }
            .onChange(of: clip) { _, _ in restart() }
            .onChange(of: paused) { _, now in now ? stop() : run() }
    }

    private func restart() {
        index = 0
        if !paused { run() }
    }

    private func run() {
        stop()
        guard clip.frames > 1 else { onFinish?(); return }
        ticker = Timer.scheduledTimer(withTimeInterval: 1 / clip.fps, repeats: true) { _ in
            step()
        }
    }

    private func step() {
        if index + 1 < clip.frames {
            index += 1
            return
        }
        if clip.loops {
            index = 0
        } else {
            stop()
            onFinish?()
        }
    }

    private func stop() {
        ticker?.invalidate()
        ticker = nil
    }
}

func runClipChecks() {
    #if DEBUG
    // frame names have to line up with what was installed, and both ends must exist
    let c = Clips.stealing
    assert(c.frame(0) == "CipetNyopet-0000")
    assert(c.last == "CipetNyopet-0011")
    assert(c.frame(-5) == c.frame(0) && c.frame(99) == c.last, "asking past either end clamps")

    // a reversed clip starts where its forward twin ends
    let fwd = Clips.stealToSitL, back = Clips.sitToStealL
    assert(fwd.name == back.name && back.reversed && !fwd.reversed)
    assert(back.frame(0) == fwd.last && back.last == fwd.frame(0))

    // a clip lands on the sprite it replaces
    let box = Clips.box(over: Tut.kanan)
    assert(abs(box.width - box.height) < 0.01, "the frames are square")
    assert(box.minX < Tut.kanan.minX && box.minY < Tut.kanan.minY, "the padding hangs outside")
    assert(box.maxX > Tut.kanan.maxX && box.maxY > Tut.kanan.maxY)

    // only the hold-this-pose clips loop; the transitions have to end so the next beat starts
    assert(Clips.stealing.loops && Clips.galau.loops)
    for once in [Clips.sitToSteal, Clips.standUp, Clips.caughtSitting, Clips.musicToAngry] {
        assert(!once.loops, "\(once.name) has to finish")
        assert(once.duration > 0.2 && once.duration < 2.5, "\(once.name) should feel snappy")
    }
    #endif
}
