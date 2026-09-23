import SwiftUI

enum Pick {
    static let prompt      = CGRect(x: 32, y: 178, width: 164, height: 130)
    static let promptSize:  CGFloat = 36

    static let pause    = CGRect(x: 790, y: 24, width: 60, height: 60)
    static let pauseArt = CGRect(x: 787.498, y: 22.254, width: 65.4371, height: 64.7477)

    static let confirm    = CGRect(x: 327,     y: 318,     width: 220,     height: 60)
    static let confirmArt = CGRect(x: 324.696, y: 315.984, width: 224.554, height: 65.0165)
    static let confirmSize: CGFloat = 40

    /// the far bench has one spot next to the victim, the near bench has two
    static let farSeats  = [Tut.seated]
    static let nearSeats = Tut.ghosts
}

struct PickVictimView: View {
    let onStart: () -> Void

    @State private var vm = PickVictimViewModel()

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                scene(space)
                if vm.tutorialUp {
                    TutorialView { withAnimation(.easeInOut(duration: 0.3)) { vm.tutorialFinished() } }
                        .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
    }

    private func scene(_ space: DesignSpace) -> some View {
        ZStack(alignment: .topLeading) {
            Image("menu_road").resizable().scaledToFill()
                .frame(width: space.px(DesignSpace.screen.width),
                       height: space.px(DesignSpace.screen.height))
                .position(x: space.x(DesignSpace.screen.width / 2),
                          y: space.y(DesignSpace.screen.height / 2))

            TutorialAngkot(show: show, space: space,
                           ghostSeats: seats, thiefAt: thiefSpot)
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
        var s: TutorialStep.Show = [.kid]
        switch vm.victim {
        case .farBench:  s.insert(.hotKiriB)
        case .nearBench: s.insert(.hotKanan)
        case nil:        return [.onPavement]
        }
        s.insert(vm.stage == .ready ? .onBoard : .seatGhosts)
        return s
    }

    private var seats: [CGRect] {
        vm.victim == .farBench ? Pick.farSeats : Pick.nearSeats
    }

    private var thiefSpot: CGRect {
        guard let i = vm.seat, seats.indices.contains(i) else { return Tut.seated }
        return seats[i]
    }

    // MARK: tap targets, only live once the tutorial is out of the way

    @ViewBuilder private func targets(_ space: DesignSpace) -> some View {
        switch vm.stage {
        case .victim:
            hit(Tut.kiriB, space) { vm.pick(.farBench) }
            hit(Tut.kanan, space) { vm.pick(.nearBench) }
        case .seat:
            ForEach(seats.indices, id: \.self) { i in
                hit(seats[i], space) { vm.take(seat: i) }
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
            Button(action: onStart) {
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

#Preview(traits: .landscapeLeft) { PickVictimView {} }
