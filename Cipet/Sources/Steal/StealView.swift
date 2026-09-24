import SwiftUI

struct StealView: View {
    let victim: Seating.Person
    let thiefSeat: CGRect
    let cast: Arrangement
    /// the round is over and the player has chosen where to go. the round never leaves on
    /// its own — winning or getting caught shows a result here, it does not pop the screen.
    enum Exit { case nextRound(RoundResult), endGame(RoundResult), home }
    let onDone: (Exit) -> Void

    @State private var vm: StealViewModel
    @State private var beat: ThiefActor.Beat = .sitting
    /// held back until the thief has finished reacting, so the endings dont cut him off
    @State private var showEnding = false
    private let clock = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    init(victim: Seating.Person, thiefSeat: CGRect, cast: Arrangement,
         onDone: @escaping (Exit) -> Void) {
        self.victim = victim
        self.thiefSeat = thiefSeat
        self.cast = cast
        self.onDone = onDone
        _vm = State(initialValue: StealViewModel(victim: victim, thiefSeat: thiefSeat))
    }

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                scene(space)
                grabArea(space)
                if vm.phase == .penalty { PenaltyOverlay(count: vm.stopFor, space: space) }
                if vm.phase == .paused {
                    PausedCard(space: space, onResume: vm.resume) { onDone(.home) }
                }
                if vm.phase == .succeeded && showEnding {
                    SucceedCard(remaining: vm.clock, value: Steal.itemValue, space: space,
                                onNext: { Audio.shared.play(.leave); onDone(.nextRound(result)) },
                                onEnd: { onDone(.endGame(result)) })
                        .transition(.opacity)
                }
                if vm.phase == .caught && showEnding {
                    JailScreen(space: space) { onDone(.endGame(result)) }.transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
        .onReceive(clock) { _ in vm.tick(1.0 / 60) }
        .onChange(of: vm.holding) { _, down in
            guard vm.running else { return }
            beat = down ? .reaching : .returning
            if down { Audio.shared.play(.grab) }
        }
        .onChange(of: vm.suspicion) { _, _ in Audio.shared.play(.suspicion) }
        .onChange(of: vm.phase) { _, p in
            // getting clocked is the thief's moment, not the screen's. he flinches whether
            // it's a cooldown or the real thing, and the endings wait for him to land it.
            switch p {
            case .penalty:   beat = .caught(midSteal: midSteal); Audio.shared.play(.warning)
            case .caught:    beat = .caught(midSteal: midSteal); Audio.shared.play(.fight)
            case .stealing:  if isFlinching { beat = .sitting }
            case .succeeded: beat = .standing; Audio.shared.play(.stole)
            case .paused:    break
            }
        }
        .task { runStealChecks(); runJailChecks(); runThiefChecks(); runClipChecks() }
    }

    /// he reaches towards whoever he's robbing
    private var reachingLeft: Bool { Seating.spot(victim).midX < thiefSeat.midX }

    private var midSteal: Bool { beat == .reaching || beat == .stealing }
    private var isFlinching: Bool { if case .caught = beat { return true }; return false }

    /// what this round was worth, whichever way it ended
    private var result: RoundResult {
        RoundResult(value: vm.phase == .succeeded ? Steal.itemValue : 0,
                    time: Steal.round - vm.timeLeft)
    }

    /// one beat hands over to the next, so nothing overlaps
    private func finished(_ done: ThiefActor.Beat) {
        switch done {
        case .reaching:  if vm.holding { beat = .stealing }
        case .returning: beat = .sitting
        // the flinch also ends a cooldown, and that one has no ending to show
        case .caught where vm.phase != .caught: break
        case .standing:
            // he's up, so the takings land with him
            Audio.shared.play(.coins)
            withAnimation(.easeInOut(duration: 0.25)) { showEnding = true }
        case .caught:
            withAnimation(.easeInOut(duration: 0.25)) { showEnding = true }
        default: break
        }
    }

    private func scene(_ space: DesignSpace) -> some View {
        ZStack(alignment: .topLeading) {
            Image("menu_road").resizable().scaledToFill()
                .frame(width: space.px(DesignSpace.screen.width),
                       height: space.px(DesignSpace.screen.height))
                .position(x: space.x(DesignSpace.screen.width / 2),
                          y: space.y(DesignSpace.screen.height / 2))

            TutorialAngkot(show: [.kid], space: space, hot: victim,
                           cast: cast, aware: vm.aware)
            ThiefActor(beat: beat, seat: thiefSeat, reachingLeft: reachingLeft,
                       space: space, paused: vm.phase == .paused, onFinish: finished)
            TutorialHUD(show: [], clock: vm.clock, space: space)
            pauseButton(space)

            StealBar(progress: vm.grab, space: space)
            SuspicionBar(lit: vm.suspicion, space: space)
        }
    }

    /// hold anywhere over the bar to fill it. letting go, or getting spotted, drops it.
    private func grabArea(_ space: DesignSpace) -> some View {
        place(Tut.inBar(Tut.track.insetBy(dx: 0, dy: -18)), space) {
            Rectangle().fill(.clear).contentShape(Rectangle())
        }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if vm.running { vm.holding = true } }
            .onEnded   { _ in vm.holding = false })
        .allowsHitTesting(vm.running)
    }

    private func pauseButton(_ space: DesignSpace) -> some View {
        place(Pick.pauseArt, space) {
            Button { vm.pause() } label: { Image("pv_pause").resizable() }
                .buttonStyle(PressStyle())
        }
    }
}
