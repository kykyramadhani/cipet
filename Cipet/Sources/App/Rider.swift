import SwiftUI

// everybody who can ride in the back. which seat a face fits is decided by which way it's
// drawn, so the pools are split that way and a round only ever draws from the right one.
enum Rider: CaseIterable, Hashable {
    // drawn facing the front, so you see their face. the far bench.
    case frontA, frontB, music, sleepy
    // drawn from behind. the near bench. no animated art for these yet.
    case backA

    var facing: Seating.Facing {
        switch self {
        case .frontA, .frontB, .music, .sleepy: return .front
        case .backA:                            return .back
        }
    }

    /// the animated ones, and which of their state words means which mood
    var moves: Moves? {
        switch self {
        case .music:  return Moves(who: "Music",  calm: "Galau", alert: "Idle", angry: ["Marah", "Angry"])
        case .sleepy: return Moves(who: "Sleepy", calm: "Sleep", alert: "Idle", angry: ["Angry", "Marah"])
        default:      return nil
        }
    }

    var animated: Bool { moves != nil }

    var art: String {
        switch self {
        case .frontA: return "tut_kiri_a"
        case .frontB: return "tut_kiri_b"
        case .backA:  return "tut_kanan"
        case .music, .sleepy:
            return moves.flatMap { $0.rest($0.calm) }?.frame(0) ?? ""
        }
    }

    /// the same drawing in Yellow/50. only the flat cast have one — the animated ones get a
    /// ring round them instead, so they keep their own frames.
    var hotArt: String? { animated ? nil : art + "_hot" }

    /// only offer a face we actually shipped the art for. drop the missing frames into the
    /// catalog and that face joins the pool on its own, no code change.
    var installed: Bool { UIImage(named: art) != nil }

    static func pool(_ facing: Seating.Facing) -> [Rider] {
        allCases.filter { $0.facing == facing && $0.installed }
    }
}

/// how an animated passenger is feeling, which is what picks their animation. calm is
/// headphones on or dozing, alert is looking about, angry is having caught you.
enum Mood: Hashable { case calm, alert, angry }

// a character's animation sets, read off their names: "<who><State>" holds a state on a
// loop, "<who><From>-<To>" moves from one state to another. so a new set dropped in under
// that naming is found here with no code change. only the state words are listed, since
// ios has no way to list what's inside the asset catalog.
struct Moves: Equatable {
    let who: String
    let calm: String
    let alert: String
    let angry: [String]   // music's is "Marah", sleepy's is "Angry"; whichever is there

    var words: [String] { [calm, alert] + angry }

    func goal(_ mood: Mood) -> [String] {
        switch mood {
        case .calm:  return [calm]
        case .alert: return [alert]
        case .angry: return angry
        }
    }

    func move(_ from: String, _ to: String) -> Clip? {
        let c = Clip("\(who)\(from)-\(to)")
        return c.exists ? c : nil
    }

    /// a state is held on its own loop if it has one, otherwise on the last frame of the move
    /// that leads into it — music has no idle loop, he just sits there with them off
    func rest(_ state: String) -> Clip? {
        let loop = Clip(who + state, loops: true)
        if loop.exists { return loop }
        for from in words {
            if let into = move(from, state) {
                return Clip(into.name, length: 1, offset: into.frames - 1)
            }
        }
        return nil
    }

    /// the shortest run of moves from one state to any of `goals`
    func route(from start: String, to goals: [String]) -> (clips: [Clip], end: String)? {
        if goals.contains(start) { return ([], start) }
        var queue = [(start, [Clip]())]
        var seen: Set = [start]
        while !queue.isEmpty {
            let (state, path) = queue.removeFirst()
            for next in words where !seen.contains(next) {
                guard let step = move(state, next) else { continue }
                if goals.contains(next) { return (path + [step], next) }
                seen.insert(next)
                queue.append((next, path + [step]))
            }
        }
        return nil
    }
}

// an animated passenger. they rest in whatever state their mood asks for, and when the
// mood changes they play every move it takes to get there, in order, then settle.
struct RiderActor: View {
    let moves: Moves
    let mood: Mood
    var paused = false
    var ring: Color? = nil
    var ringWidth: CGFloat = 0

    /// where they'll be once everything queued has played
    @State private var state: String
    @State private var playing: Clip?
    @State private var queue: [Clip] = []
    @State private var moving = false

    init(moves: Moves, mood: Mood, paused: Bool = false, ring: Color? = nil, ringWidth: CGFloat = 0) {
        self.moves = moves
        self.mood = mood
        self.paused = paused
        self.ring = ring
        self.ringWidth = ringWidth
        let start = moves.goal(mood)[0]
        _state = State(initialValue: start)
        _playing = State(initialValue: moves.rest(start))
    }

    var body: some View {
        ZStack {
            if let playing {
                FrameAnimation(clip: playing, paused: paused, ring: ring, ringWidth: ringWidth) {
                    next()
                }
            }
        }
        .onChange(of: mood) { _, now in head(to: now) }
    }

    private func head(to mood: Mood) {
        guard let r = moves.route(from: state, to: moves.goal(mood)), !r.clips.isEmpty else { return }
        queue += r.clips
        state = r.end
        if !moving { next() }
    }

    private func next() {
        guard queue.isEmpty else {
            playing = queue.removeFirst()
            moving = true
            return
        }
        moving = false
        // settle into the state's loop. with no loop the move that got here holds its last frame
        if let rest = moves.rest(state), rest.loops { playing = rest }
    }
}

func runRiderChecks() {
    #if DEBUG
    // nobody is offered a seat their artwork doesnt face
    for f in [Seating.Facing.front, .back] {
        let pool = Rider.pool(f)
        assert(!pool.isEmpty, "\(f) seats have nobody to put in them")
        assert(pool.allSatisfy { $0.facing == f })
    }
    assert(Rider.pool(.front).contains(.sleepy) && Rider.pool(.front).contains(.music),
           "both animated faces are in the front pool")
    assert(!Rider.pool(.back).contains { $0.animated },
           "music and sleepy face forwards, they cant sit on the near bench")
    for p in Rider.pool(.front) + Rider.pool(.back) {
        assert(UIImage(named: p.art) != nil, "\(p) has no artwork")
        assert(p.animated == (p.hotArt == nil), "flat cast swap to yellow, animated ones get a ring")
    }

    // every mood is reachable from every other, using nothing but the sets' names
    for rider in [Rider.music, .sleepy] {
        let m = rider.moves!
        assert(m.rest(m.calm)?.loops == true, "\(m.who) has to idle on a loop when calm")
        assert(m.rest(m.alert) != nil, "\(m.who) needs something to show when alert")
        for from in [Mood.calm, .alert] {
            for to in [Mood.calm, .alert, .angry] where to != from {
                let r = m.route(from: m.goal(from)[0], to: m.goal(to))
                assert(r != nil && !r!.clips.isEmpty, "\(m.who) cant get from \(from) to \(to)")
            }
        }
    }
    let music = Rider.music.moves!, sleepy = Rider.sleepy.moves!
    assert(music.route(from: "Galau", to: ["Idle"])!.clips.map(\.name) == ["MusicGalau-Idle"])
    assert(music.route(from: "Idle", to: ["Galau"])!.clips.map(\.name) == ["MusicIdle-Galau"])
    assert(music.route(from: "Galau", to: music.angry)!.clips.map(\.name) == ["MusicGalau-Marah"])
    assert(music.route(from: "Idle", to: music.angry)!.clips.map(\.name) == ["MusicIdle-Angry"])
    assert(sleepy.route(from: "Sleep", to: sleepy.angry)!.clips.map(\.name)
           == ["SleepySleep-Idle", "SleepyIdle-Angry"], "asleep has to wake up before getting angry")
    assert(music.rest("Idle")?.frame(0) == "MusicGalau-Idle-0035",
           "no idle loop for music, so he holds the end of taking them off")
    assert(sleepy.rest("Idle")?.name == "SleepyIdle" && sleepy.rest("Sleep")?.name == "SleepySleep")
    #endif
}
