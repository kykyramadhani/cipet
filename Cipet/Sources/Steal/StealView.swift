import SwiftUI

struct StealView: View {
    let victim: Seating.Person
    let thiefSeat: CGRect
    let cast: Arrangement
    let round: Int
    /// items taken over the rounds already finished
    let items: Int
    /// the round is over and the player has chosen where to go. the round never leaves on
    /// its own — winning or getting caught shows a result here, it does not pop the screen.
    enum Exit { case nextRound(RoundResult), endGame(RoundResult, Ending), home }
    let onDone: (Exit) -> Void

    @State private var vm: StealViewModel
    @State private var beat: ThiefActor.Beat = .sitting
    /// held back until the thief has finished reacting, so the endings dont cut him off
    @State private var showEnding = false
    /// when he got caught, so the cage can wait for the passengers to finish turning on him
    @State private var caughtAt: Date?
    private let clock = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    init(victim: Seating.Person, thiefSeat: CGRect, timeLeft: Double, cast: Arrangement, round: Int,
         items: Int = 0,
         onDone: @escaping (Exit) -> Void) {
        self.victim = victim
        self.thiefSeat = thiefSeat
        self.cast = cast
        self.round = round
        self.items = items
        self.onDone = onDone
        _vm = State(initialValue: StealViewModel(victim: victim, thiefSeat: thiefSeat, cast: cast,
                                                 timeLeft: timeLeft))
    }

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                // flattened first, or each sprite gets blurred inside its own box
                scene(space)
                    .compositingGroup()
                    .blur(radius: vm.phase == .penalty ? space.px(Cooldown.blur) : 0, opaque: true)
                grabArea(space)
                pauseButton(space)
                if vm.phase == .penalty {
                    PenaltyOverlay(count: vm.stopFor, space: space)
                    TutorialHUD(show: [], clock: vm.clock, space: space,
                                clockOnly: true, low: vm.lowOnTime)
                }
                if vm.phase == .paused {
                    PausedCard(space: space, onResume: vm.resume) { onDone(.home) }
                }
                if vm.phase == .succeeded && showEnding {
                    SucceedCard(remaining: vm.clock, value: vm.loot,
                                victim: victim, cast: cast, space: space,
                                onNext: { Audio.shared.play(.leave); onDone(.nextRound(result)) },
                                onEnd: { onDone(.endGame(result, .walkedAway)) })
                        .transition(.opacity)
                }
                if vm.phase == .caught && showEnding {
                    // spotted three times is the cage, running out of time is just Failed
                    JailScreen(space: space, jailed: !vm.timedOut) {
                        onDone(.endGame(result, vm.timedOut ? .failed : .jailed))
                    }
                    .transition(.opacity)
                }
            }
            .coordinateSpace(name: Menu.space)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
        .onReceive(clock) { _ in vm.tick(1.0 / 60) }
        .onChange(of: vm.holding) { _, down in
            guard vm.running else { return }
            beat = down ? .reaching : .returning
            if down {
                Audio.shared.play(.grab)
                Haptics.grab()
            }
        }
        .onChange(of: ticking, initial: true) { _, on in Audio.shared.ticking(on) }
        .onDisappear { Audio.shared.ticking(false) }
        .onChange(of: vm.suspicion) { _, _ in Audio.shared.play(.suspicion) }
        .onChange(of: vm.phase) { _, p in
            // getting clocked is the thief's moment, not the screen's. he flinches whether
            // it's a cooldown or the real thing, and the endings wait for him to land it.
            switch p {
            case .penalty:   beat = .caught(midSteal: midSteal); Audio.shared.play(.warning)
            case .caught:
                beat = .caught(midSteal: midSteal); caughtAt = .now; Audio.shared.play(.fight)
            case .stealing:  if isFlinching { beat = .sitting }
            case .succeeded: beat = .standing; Audio.shared.play(.stole)
            case .paused:    break
            }
        }
        .task { Haptics.warmUp(); runStealChecks(); runPortraitChecks(); runJailChecks(); runThiefChecks(); runClipChecks(); runCooldownChecks(); runBarChecks() }
    }

    /// the clock is only audible while it's actually counting down on him: not once the
    /// round is over, and not behind the pause card. a cooldown still counts, because the
    /// clock is still running through it.
    private var ticking: Bool {
        vm.lowOnTime && !vm.over && vm.phase != .paused && vm.timeLeft > 0
    }

    /// he reaches towards whoever he's robbing
    private var reachingLeft: Bool { Seating.spot(victim).midX < thiefSeat.midX }

    private var midSteal: Bool { beat == .reaching || beat == .stealing }
    private var isFlinching: Bool { if case .caught = beat { return true }; return false }

    /// what this round was worth, whichever way it ended
    private var result: RoundResult {
        RoundResult(value: vm.phase == .succeeded ? vm.loot : 0,
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
            // everyone's current face -> MARAH, then a beat of it, then the cage
            let anger = vm.angerTime > 0 ? vm.angerTime + Steal.angerHold : 0
            let left = anger - Date.now.timeIntervalSince(caughtAt ?? .now)
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, left)) {
                withAnimation(.easeInOut(duration: 0.25)) { showEnding = true }
            }
        default: break
        }
    }

    private func scene(_ space: DesignSpace) -> some View {
        ZStack(alignment: .topLeading) {
            road(space)

            TutorialAngkot(show: [.kid], space: space, thiefAt: thiefSeat, hot: victim,
                           cast: cast, aware: vm.bars, moods: vm.moods,
                           paused: vm.phase == .paused, colored: true,
                           thief: AnyView(ThiefActor(beat: beat, seat: thiefSeat, reachingLeft: reachingLeft,
                                                     behind: Seating.bench(of: thiefSeat) == 1,
                                                     space: space, paused: vm.phase == .paused,
                                                     onFinish: finished)))
                .offset(y: space.px(Steal.angkotDrop))
            TutorialHUD(show: [], clock: vm.clock, space: space, low: vm.lowOnTime, items: items)
            roundTag(space)

            StealBar(progress: vm.grab, space: space)
            SuspicionBar(lit: vm.suspicion, space: space)
        }
    }

    /// two copies of the road side by side, slid along. the seam lands off screen because
    /// the art tiles, so it reads as one continuous road going past.
    private func road(_ space: DesignSpace) -> some View {
        let w = DesignSpace.screen.width
        let h = DesignSpace.screen.height
        return HStack(spacing: 0) {
            ForEach(0..<2, id: \.self) { _ in
                Image("menu_road").resizable().scaledToFill()
                    .frame(width: space.px(w), height: space.px(h))
            }
        }
        .frame(width: space.px(w * 2), height: space.px(h), alignment: .leading)
        .position(x: space.x(w - vm.road * w), y: space.y(h / 2))
    }

    /// hold anywhere on the screen to fill the bar — his hand is already on the pocket,
    /// you're only deciding how long to leave it there. letting go, or getting spotted,
    /// drops it. the pause button is drawn over this, so it still takes its own taps.
    private func grabArea(_ space: DesignSpace) -> some View {
        Rectangle().fill(.clear).contentShape(Rectangle())
            .frame(width: space.px(DesignSpace.screen.width),
                   height: space.px(DesignSpace.screen.height))
            .position(x: space.x(DesignSpace.screen.width / 2),
                      y: space.y(DesignSpace.screen.height / 2))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if vm.running { vm.holding = true } }
                .onEnded   { _ in vm.holding = false })
            .allowsHitTesting(vm.running)
    }

    private func roundTag(_ space: DesignSpace) -> some View {
        Group {
            // the art is the tab drawn upside down
            place(Steal.roundArt, space) { Image("round_tag").resizable().scaleEffect(y: -1) }
            Text("\(t("Round")) #\(round)")
                .font(.skranji(space.px(Steal.roundSize), bold: false))
                .foregroundStyle(Ink.black)
                .fixedSize()
                .position(x: space.x(Steal.roundTag.midX), y: space.y(Steal.roundTag.midY))
        }
    }

    private func pauseButton(_ space: DesignSpace) -> some View {
        place(Steal.pauseArt, space) {
            Button { vm.pause() } label: { Image("pv_pause").resizable() }
                .buttonStyle(PressStyle())
        }
    }
}
