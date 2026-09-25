import SwiftUI

// every animation set in the catalog, by name. ios cant list an asset catalog, so a build
// phase writes the names out (see project.yml) and this reads them back. "<who><State>" is a
// state on a loop, "<who><From>-<To>" is the move between two; the frame number isnt part of it.
enum FrameSets {
    static let names: [String] = {
        guard let url = Bundle.main.url(forResource: "frame_sets", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }()

    /// who a set belongs to and the state words in it: "BehindMusicGalau-Idle" is
    /// ("BehindMusic", ["Galau", "Idle"]). the state is the last capitalised word before the dash.
    static func parse(_ name: String) -> (who: String, states: [String])? {
        let parts = name.split(separator: "-").map(String.init)
        guard let head = parts.first, parts.count <= 2,
              let cut = head.lastIndex(where: \.isUppercase), cut != head.startIndex else { return nil }
        return (String(head[..<cut]), [String(head[cut...])] + parts.dropFirst())
    }

    /// who -> every state word their sets mention
    static let states: [String: Set<String>] = names.reduce(into: [:]) { all, name in
        guard let (who, words) = parse(name) else { return }
        all[who, default: []].formUnion(words)
    }
}

// one character in the back of the angkot. who they are, which way they face and how they
// move all come from their sets' names, so a new character is a new folder of frames.
struct Rider: Hashable {
    let who: String

    /// drawn from behind means the near bench, where you see their backs
    var facing: Seating.Facing { who.hasPrefix("Behind") ? .back : .front }

    /// the same person whichever way round they're drawn, so nobody is dealt twice
    var person: String { who.replacingOccurrences(of: "Behind", with: "") }

    /// a duo comes as a pair: the left half is dealt, the right half sits straight beside it
    var partner: Rider? {
        who.contains("LeftDuo") ? Rider(who: who.replacingOccurrences(of: "LeftDuo", with: "RightDuo")) : nil
    }
    var isRightHalf: Bool { who.contains("RightDuo") }

    var moves: Moves { Moves(who: who, words: FrameSets.states[who] ?? []) }

    /// a still of them idle, for anywhere that needs a picture rather than the animation
    var art: String { moves.rest(moves.alert)?.frame(0) ?? "" }

    /// the kid, and everyone the rounds can deal. the thief, the driver and the kid arent dealt.
    static let kid = Rider(who: "Boy")
    static var all: [Rider] {
        FrameSets.states.keys.filter { !$0.contains("Cipet") && $0 != kid.who }.sorted().map(Rider.init)
    }

    /// who can be dealt into a seat facing this way. a duo's right half comes with its left.
    static func pool(_ facing: Seating.Facing) -> [Rider] {
        all.filter { $0.facing == facing && !$0.isRightHalf }
    }
}

/// what an animated passenger is doing. calm is their own thing (music on, asleep, chatting)
/// and not watching; alert is idle and looking about; angry is only ever for getting caught.
enum Mood: Hashable { case calm, alert, angry }

// a character's sets read as states and the moves between them
struct Moves: Equatable {
    let who: String
    let calm: String      // the non-idle state: Galau, Sleep, Talking. the kid only has Idle.
    let alert: String
    let angry: String

    init(who: String, words: Set<String>) {
        self.who = who
        alert = "Idle"
        angry = "Angry"
        calm = words.subtracting([alert, angry]).sorted().first ?? alert
    }

    var words: [String] { [calm, alert, angry] }

    func goal(_ mood: Mood) -> String {
        switch mood {
        case .calm:  return calm
        case .alert: return alert
        case .angry: return angry
        }
    }

    func move(_ from: String, _ to: String) -> Clip? {
        let c = Clip("\(who)\(from)-\(to)")
        return c.exists ? c : nil
    }

    /// a state is held on its own loop if it has one, otherwise on the last frame of the move
    /// that leads into it — music has no idle loop, and angry is the end of getting there
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

    /// the shortest run of moves from one state to another
    func route(from start: String, to goal: String) -> (clips: [Clip], end: String)? {
        if start == goal { return ([], start) }
        var queue = [(start, [Clip]())]
        var seen: Set = [start]
        while !queue.isEmpty {
            let (state, path) = queue.removeFirst()
            for next in words where !seen.contains(next) {
                guard let step = move(state, next) else { continue }
                if next == goal { return (path + [step], next) }
                seen.insert(next)
                queue.append((next, path + [step]))
            }
        }
        return nil
    }

    /// how long getting from one mood to another takes on screen
    func time(from: Mood, to: Mood) -> Double {
        route(from: goal(from), to: goal(to))?.clips.reduce(0) { $0 + $1.duration } ?? 0
    }
}

// an animated passenger. they rest in whatever state their mood asks for, and when the
// mood changes they play every move it takes to get there, once each, in order, then settle.
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
        let start = moves.goal(mood)
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
    // the names split into who and state, whatever the character
    assert(FrameSets.parse("BehindMusicGalau-Idle")! == ("BehindMusic", ["Galau", "Idle"]))
    assert(FrameSets.parse("SleepySleep")! == ("Sleepy", ["Sleep"]))
    assert(FrameSets.parse("LeftDuoTalking-Idle")! == ("LeftDuo", ["Talking", "Idle"]))
    assert(FrameSets.parse("Driver") == nil, "a single word is nobody's state")

    assert(!FrameSets.names.isEmpty, "the build phase didnt write frame_sets.txt")
    // every set it lists is really there, and the list is the whole folder
    for name in FrameSets.names { assert(Clip(name).exists, "\(name) is listed but has no frames") }

    // both benches have somebody, and nobody is dealt onto the wrong one
    for f in [Seating.Facing.front, .back] {
        let pool = Rider.pool(f)
        assert(!pool.isEmpty, "\(f) seats have nobody to put in them")
        assert(pool.allSatisfy { $0.facing == f && ($0.facing == .back) == $0.who.hasPrefix("Behind") })
    }
    // the old flat drawings are gone for good
    for gone in ["tut_kiri_a", "tut_kiri_b", "tut_kanan", "tut_bocah", "tut_sopir"] {
        assert(UIImage(named: gone) == nil, "\(gone) should have been removed")
    }

    // every passenger can go idle <-> their own thing, and get angry from either
    for rider in Rider.all {
        let m = rider.moves
        assert(m.calm != m.alert, "\(m.who) has nothing to do but idle")
        assert(m.rest(m.calm)?.loops == true, "\(m.who) has to hold \(m.calm) on a loop")
        assert(m.rest(m.alert) != nil && m.rest(m.angry) != nil, "\(m.who) cant be shown idle or angry")
        for (a, b) in [(Mood.calm, Mood.alert), (.alert, .calm), (.calm, .angry), (.alert, .angry)] {
            let r = m.route(from: m.goal(a), to: m.goal(b))
            assert(r != nil && !r!.clips.isEmpty, "\(m.who) cant get from \(a) to \(b)")
            assert(r!.clips.allSatisfy { !$0.loops }, "a move plays once, it never loops")
        }
        if let p = rider.partner { assert(Rider.all.contains(p), "\(rider.who) has no other half") }
    }
    // galau to idle is exactly the one move, and asleep has to wake before getting angry
    let music = Rider(who: "Music").moves, sleepy = Rider(who: "Sleepy").moves
    assert(music.route(from: "Galau", to: "Idle")!.clips.map(\.name) == ["MusicGalau-Idle"])
    assert(sleepy.route(from: "Sleep", to: "Angry")!.clips.map(\.name) == ["SleepySleep-Idle", "SleepyIdle-Angry"])
    assert(music.rest("Idle")?.frame(0) == "MusicGalau-Idle-0035", "no idle loop, so he holds the end of it")

    // the kid only ever idles
    assert(Rider.kid.moves.calm == "Idle" && Rider.kid.moves.rest("Idle")?.loops == true)
    #endif
}
