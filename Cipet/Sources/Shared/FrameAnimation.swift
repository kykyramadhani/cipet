import SwiftUI

// the animated art comes as numbered png sequences, all 300x300 with the character padded
// the same way. a set is everything sharing a name, "MusicGalau-Idle-0000" to "-0035" is one
// animation of 36 frames, and how many there are is counted off the catalog rather than
// typed in, so a set that gains or loses frames just works.
struct Clip: Equatable {
    let name: String
    var loops = false
    /// played backwards. a few transitions only exist one way round and the reverse is the
    /// other half of the move, so this saves shipping the same drawings twice.
    var reversed = false
    /// only this many frames, and starting this far in. length 1 is a still of one frame.
    var length: Int? = nil
    var offset = 0

    init(_ name: String, loops: Bool = false, reversed: Bool = false,
         length: Int? = nil, offset: Int = 0) {
        self.name = name
        self.loops = loops
        self.reversed = reversed
        self.length = length
        self.offset = offset
    }

    var fps: Double { 24 }
    var frames: Int { length ?? max(0, Clip.count(name) - offset) }
    var exists: Bool { Clip.count(name) > 0 }
    var duration: Double { Double(frames) / fps }

    func frame(_ i: Int) -> String {
        let n = min(max(0, i), max(0, frames - 1))
        return String(format: "%@-%04d", name, offset + (reversed ? frames - 1 - n : n))
    }

    var last: String { frame(frames - 1) }

    /// -0000, -0001, ... until the next one isnt there. counted once per set.
    private static var counts: [String: Int] = [:]
    static func count(_ name: String) -> Int {
        if let n = counts[name] { return n }
        var n = 0
        while UIImage(named: String(format: "%@-%04d", name, n)) != nil { n += 1 }
        counts[name] = n
        return n
    }
}

/// the thief's sets. the passengers' are found through their Moves instead.
enum Clips {
    static let size = CGSize(width: 300, height: 300)

    // where the drawn character sits inside that 300x300, measured off the frames. the flat
    // artwork is cropped tight, so a clip has to be scaled and nudged to land on the same spot.
    private static let ink = CGRect(x: 64, y: 39, width: 173, height: 220)

    /// the driver is drawn a little bigger in his frame than everyone else
    static let driverInk = CGRect(x: 62, y: 23, width: 179, height: 237)

    /// the rect to draw a clip in so its character lands on the flat sprite's box
    static func box(over spot: CGRect, ink: CGRect = ink) -> CGRect {
        let k = spot.height / ink.height
        return CGRect(x: spot.minX - ink.minX * k, y: spot.minY - ink.minY * k,
                      width: size.width * k, height: size.height * k)
    }

    /// one of the thief's moves: "Idle-Nyopet", "Nyopet", "Nyopet-Idle", "Nyopet-Caught",
    /// "Caught", "Idle-Standup". reaching left is its own drawing ("Left..."), and so is sitting
    /// on the near bench with his back to us ("Behind..."). when a drawing isnt there yet it
    /// falls back to the nearest one that is, so a new set is used the moment it's added.
    static func thief(_ move: String, left: Bool, behind: Bool, loops: Bool = false) -> Clip {
        // from behind he only ever uses the Behind drawings — never turns round to face us
        let sides = behind ? [(left, true), (false, true)] : [(left, false), (false, false)]
        for (l, b) in sides {
            let c = Clip((l ? "Left" : "") + (b ? "Behind" : "") + "Cipet" + move, loops: loops)
            if c.exists { return c }
        }
        // a move not drawn from behind yet: caught mid-steal pulls his hand back, anything
        // else he stays sat with his back to us
        if behind, move == "Nyopet-Caught" { return thief("Nyopet-Idle", left: left, behind: true) }
        return behind ? behindIdle(left: left) : Clip("Cipet" + move, loops: loops)
    }

    /// him sat still with his back to us: where the return from reaching ends
    static func behindIdle(left: Bool) -> Clip {
        let back = thief("Nyopet-Idle", left: left, behind: true)
        return Clip(back.name, length: 1, offset: back.frames - 1)
    }
}

// plays a clip. a looping clip runs until it's swapped out; a one-shot holds on its last
// frame and calls `onFinish`, which is what lets one beat hand over to the next.
struct FrameAnimation: View {
    let clip: Clip
    var paused = false
    /// marks this one as picked without touching its frames
    var ring: Color? = nil
    var ringWidth: CGFloat = 0
    var onFinish: (() -> Void)?

    @State private var index = 0
    @State private var ticker: Timer?

    var body: some View {
        Sprite(name: clip.frame(index), ring: ring, ringWidth: ringWidth)
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
    // frame counts come off the catalog, so check the counter against sets we know
    let known = ["CipetNyopet": 12, "CipetIdle-Nyopet": 24, "MusicGalau": 15, "MusicGalau-Idle": 36,
                 "MusicGalau-Angry": 18, "BehindSleepySleep-Idle": 52, "BoyIdle": 24,
                 "RightDuoTalking": 12, "LeftDuoTalking": 1, "MusicIdle-Angry": 18, "MusicIdle-Galau": 36,
                 "SleepyIdle": 70, "SleepyIdle-Sleep": 15, "SleepySleep": 30,
                 "SleepySleep-Idle": 44, "SleepyIdle-Angry": 18]
    for (name, n) in known { assert(Clip.count(name) == n, "\(name) should have \(n) frames") }
    assert(!Clip("NoSuchSet").exists && Clip("NoSuchSet").frames == 0)

    let c = Clips.thief("Nyopet", left: false, behind: false, loops: true)
    assert(c.frame(0) == "CipetNyopet-0000")
    assert(c.last == "CipetNyopet-0011")
    assert(c.frame(-5) == c.frame(0) && c.frame(99) == c.last, "asking past either end clamps")

    // a reversed clip starts where its forward twin ends
    let fwd = Clip("LeftCipetNyopet-Idle"), back = Clip("LeftCipetNyopet-Idle", reversed: true)
    assert(back.reversed && !fwd.reversed)
    assert(back.frame(0) == fwd.last && back.last == fwd.frame(0))

    // a still is one frame of a set, held
    let still = Clip("MusicGalau-Idle", length: 1, offset: 35)
    assert(still.frames == 1 && still.frame(0) == "MusicGalau-Idle-0035")

    // a clip lands on the sprite it replaces
    let box = Clips.box(over: Tut.kanan)   // the near-middle seat's old drawing box
    assert(abs(box.width - box.height) < 0.01, "the frames are square")
    assert(box.minX < Tut.kanan.minX && box.minY < Tut.kanan.minY, "the padding hangs outside")
    assert(box.maxX > Tut.kanan.maxX && box.maxY > Tut.kanan.maxY)

    // only the hold-this-pose clips loop; the transitions have to end so the next beat starts
    assert(c.loops)
    for once in ["Idle-Nyopet", "Idle-Standup", "Caught"].map({ Clips.thief($0, left: false, behind: false) })
                + [Clip("MusicIdle-Angry")] {
        assert(!once.loops, "\(once.name) has to finish")
        assert(once.duration > 0.2 && once.duration < 2.5, "\(once.name) should feel snappy")
    }
    #endif
}
