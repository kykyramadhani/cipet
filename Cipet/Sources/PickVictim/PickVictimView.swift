import SwiftUI

enum Pick {
    static let prompt      = CGRect(x: 32, y: 178, width: 164, height: 130)
    static let promptSize:  CGFloat = 36

    static let pause    = CGRect(x: 790, y: 24, width: 60, height: 60)
    static let pauseArt = CGRect(x: 787.498, y: 22.254, width: 65.4371, height: 64.7477)

    static let confirm    = CGRect(x: 327,     y: 318,     width: 220,     height: 60)
    static let confirmArt = CGRect(x: 324.696, y: 315.984, width: 224.554, height: 65.0165)
    static let confirmSize: CGFloat = 40

}

struct PickVictimView: View {
    let cast: Arrangement
    let showTutorial: Bool
    let onTutorialDone: () -> Void
    let onStart: (Seating.Person, CGRect) -> Void

    @State private var vm = PickVictimViewModel()

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                scene(space)
                if vm.tutorialUp {
                    TutorialView {
                        withAnimation(.easeInOut(duration: 0.3)) { vm.tutorialFinished() }
                        onTutorialDone()
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
        .task { runSeatingChecks(); vm.tutorialUp = showTutorial }
    }

    private func scene(_ space: DesignSpace) -> some View {
        ZStack(alignment: .topLeading) {
            Image("menu_road").resizable().scaledToFill()
                .frame(width: space.px(DesignSpace.screen.width),
                       height: space.px(DesignSpace.screen.height))
                .position(x: space.x(DesignSpace.screen.width / 2),
                          y: space.y(DesignSpace.screen.height / 2))

            TutorialAngkot(show: show, space: space,
                           ghostSeats: vm.seatsOnOffer, thiefAt: thiefSpot,
                           hot: vm.victim, cast: cast, dimFixed: true)
            if vm.onPavement { TutorialPavement(space: space) }
            TutorialHUD(show: [], clock: "1:30", space: space)

            prompt(space)
            pauseButton(space)
            confirmButton(space)
            targets(space)
        }
    }

    // MARK: what the angkot is showing right now

    private var show: TutorialStep.Show {
        // the kid is sat there from the start, same as the driver
        guard vm.victim != nil else { return [.onPavement, .kid] }
        return vm.stage == .ready ? [.kid, .onBoard] : [.kid, .seatGhosts]
    }

    private var thiefSpot: CGRect { vm.seat ?? Tut.seated }

    // MARK: tap targets, only live once the tutorial is out of the way

    @ViewBuilder private func targets(_ space: DesignSpace) -> some View {
        switch vm.stage {
        case .victim:
            ForEach(Seating.victims, id: \.self) { who in
                hit(Seating.spot(who), space) { vm.pick(who) }
            }
        case .seat:
            ForEach(vm.seatsOnOffer, id: \.self) { spot in
                hit(spot, space) { vm.take(seat: spot) }
            }
        case .ready:
            EmptyView()
        }
    }

    private func hit(_ r: CGRect, _ space: DesignSpace,
                     _ action: @escaping () -> Void) -> some View {
        place(Tut.inAngkot(r), space) {
            Rectangle().fill(.clear).contentShape(Rectangle()).onTapGesture(perform: action)
        }
    }

    // MARK: chrome

    private func prompt(_ space: DesignSpace) -> some View {
        place(Pick.prompt, space) {
            Text(vm.prompt)
                .font(.skranji(space.px(Pick.promptSize), bold: false))
                .foregroundStyle(Ink.soft)
                .lineSpacing(space.px(Pick.promptSize * 0.2))
                .fixedSize()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func pauseButton(_ space: DesignSpace) -> some View {
        place(Pick.pauseArt, space) { Image("pv_pause").resizable() }
    }

    private func confirmButton(_ space: DesignSpace) -> some View {
        place(Pick.confirmArt, space) {
            Button { if let v = vm.victim, let seat = vm.seat { onStart(v, seat) } } label: {
                ZStack {
                    Image(vm.canConfirm ? "menu_play_button" : "pv_confirm_off").resizable()
                    Text("Confirm")
                        .font(.skranji(space.px(Pick.confirmSize), bold: false))
                        .foregroundStyle(vm.canConfirm ? Ink.soft : Color(white: 250 / 255))
                }
            }
            .buttonStyle(PressStyle())
            .disabled(!vm.canConfirm)
        }
    }
}

#Preview(traits: .landscapeLeft) {
    PickVictimView(cast: .random(avoiding: nil), showTutorial: false, onTutorialDone: {}) { _, _ in }
}
