import SwiftUI

enum Pick {
    // the instruction is a yellow tab hung off the bottom of the timer: the hold-to-fill
    // tab's shape turned upside down. the art bleeds past its 200x32 box like the others.
    static let tab     = CGRect(x: 337, y: Tut.clockPanel.maxY, width: 200, height: 32)
    static let tabArt  = CGSize(width: 199.094, height: 36.0456)
    static let tabLift: CGFloat = 2.3466       // how far the flipped art pokes above the box
    static let tabText  = CGRect(x: 337, y: Tut.clockPanel.maxY + 5.35, width: 200, height: 21.262)
    static let tabSize: CGFloat = 15.652

    /// the angkot sits this much lower here than on the other screens, to make room for the tab
    static let drop: CGFloat = 20

    static let pause    = CGRect(x: 790, y: 24, width: 60, height: 60)
    static let pauseArt = CGRect(x: 787.498, y: 22.254, width: 65.4371, height: 64.7477)

    static let confirm    = CGRect(x: 327,     y: 318,     width: 220,     height: 60)
    static let confirmArt = CGRect(x: 324.696, y: 315.984, width: 224.554, height: 65.0165)
    static let confirmSize: CGFloat = 40

}

struct PickVictimView: View {
    let cast: Arrangement
    var items = 0
    let onHome: () -> Void
    let onStart: (Seating.Person, CGRect, Double) -> Void

    @State private var vm: PickVictimViewModel
    private let ticker = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    init(cast: Arrangement, items: Int = 0, onHome: @escaping () -> Void,
         onStart: @escaping (Seating.Person, CGRect, Double) -> Void) {
        self.cast = cast
        self.items = items
        self.onHome = onHome
        self.onStart = onStart
        _vm = State(initialValue: PickVictimViewModel(cast: cast))
    }

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                scene(space)
                if vm.paused {
                    PausedCard(space: space, onResume: vm.resume, onHome: onHome)
                }
            }
            .coordinateSpace(name: Menu.space)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
        .onReceive(ticker) { _ in vm.tick(1.0 / 60) }
        .onChange(of: vm.lowOnTime && vm.running, initial: true) { _, on in
            Audio.shared.ticking(on)
        }
        .onDisappear { Audio.shared.ticking(false) }
        .task { runSeatingChecks(); runPickChecks() }
    }

    private func scene(_ space: DesignSpace) -> some View {
        ZStack(alignment: .topLeading) {
            Image("menu_road").resizable().scaledToFill()
                .frame(width: space.px(DesignSpace.screen.width),
                       height: space.px(DesignSpace.screen.height))
                .position(x: space.x(DesignSpace.screen.width / 2),
                          y: space.y(DesignSpace.screen.height / 2))

            TutorialAngkot(show: show, space: space,
                           ghostSeats: vm.ghosts, thiefAt: vm.seat ?? Tut.seated,
                           hot: vm.target, cast: cast,
                           dimFixed: true, moods: cast.start)
                .offset(y: space.px(Pick.drop))
            if vm.onPavement { TutorialPavement(space: space) }
            TutorialHUD(show: [], clock: vm.clock, space: space, low: vm.lowOnTime, items: items)

            instruction(space)
            pauseButton(space)
            confirmButton(space)
            targets(space)
        }
    }

    // MARK: what the angkot is showing right now

    // the kid is sat there from the start, same as the driver. picking someone shows where
    // you could sit next to them; choosing one of those sits him down in it.
    private var show: TutorialStep.Show {
        var show: TutorialStep.Show = [.kid]
        if !vm.ghosts.isEmpty { show.insert(.seatGhosts) }
        if vm.seat != nil { show.insert(.onBoard) }
        return show
    }

    // MARK: tap targets, only live once the tutorial is out of the way

    @ViewBuilder private func targets(_ space: DesignSpace) -> some View {
        if vm.paused { EmptyView() } else {
            switch vm.stage {
            case .target:
                ForEach(cast.targets, id: \.self) { who in
                    hit(Seating.spot(who), space) { vm.pick(who) }
                }
            case .seat:
                ForEach(vm.seatsOnOffer, id: \.self) { spot in
                    hit(spot, space) { vm.take(seat: spot) }
                }
            }
        }
    }

    private func hit(_ r: CGRect, _ space: DesignSpace,
                     _ action: @escaping () -> Void) -> some View {
        place(Tut.inAngkot(r).offsetBy(dx: 0, dy: Pick.drop), space) {
            Rectangle().fill(.clear).contentShape(Rectangle()).onTapGesture(perform: action)
        }
    }

    // MARK: chrome

    private func instruction(_ space: DesignSpace) -> some View {
        Group {
            place(CGRect(x: Pick.tab.minX, y: Pick.tab.minY - Pick.tabLift,
                         width: Pick.tabArt.width, height: Pick.tabArt.height), space) {
                Image("pv_tab").resizable().scaleEffect(x: 1, y: -1)
            }
            // centred on the line's typographic width like the design does it. swiftui's
            // own Text frame runs a few points wider, so centring that drifts the words left.
            let width = GlyphLine(vm.prompt, size: Pick.tabSize).box.width
            place(CGRect(x: Pick.tabText.midX - width / 2, y: Pick.tabText.minY,
                         width: width, height: Pick.tabText.height), space) {
                Text(vm.prompt)
                    .font(.skranji(space.px(Pick.tabSize), bold: false))
                    .foregroundStyle(Ink.black)
                    .fixedSize()
                    .frame(width: space.px(width), alignment: .leading)
            }
        }
    }

    private func pauseButton(_ space: DesignSpace) -> some View {
        place(Pick.pauseArt, space) {
            Button { vm.pause() } label: { Image("pv_pause").resizable() }
                .buttonStyle(PressStyle())
        }
    }

    private func confirmButton(_ space: DesignSpace) -> some View {
        place(Pick.confirmArt, space) {
            Button {
                if let done = vm.confirm() { onStart(done.target, done.seat, vm.timeLeft) }
            } label: {
                ZStack {
                    Image(vm.canConfirm ? "menu_play_button" : "pv_confirm_off").resizable()
                    Text(t("Confirm"))
                        .font(.skranji(space.px(Pick.confirmSize), bold: false))
                        .foregroundStyle(vm.canConfirm ? Ink.soft : Color(white: 250 / 255))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)   // a longer word in another language
                        .padding(.horizontal, space.px(12))
                }
            }
            .buttonStyle(PressStyle())
            .disabled(!vm.canConfirm)
        }
    }
}

#Preview(traits: .landscapeLeft) {
    PickVictimView(cast: .random(avoiding: nil), onHome: {}) { _, _, _ in }
}
