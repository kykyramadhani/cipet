import SwiftUI

// five scenes that share one screen, so the differences live in TutorialStep and everything
// here just reads them. the angkot is parked, nothing scrolls. the only moving part is the
// steal bar filling on a loop.
struct TutorialView: View {
    let onFinish: () -> Void

    @State private var vm = TutorialViewModel()
    private let ticker = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)
            let step = vm.step

            ZStack(alignment: .topLeading) {
                scene(step, space).allowsHitTesting(false)
                card(step, space)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
        .onReceive(ticker) { _ in vm.tick(1.0 / 60) }
        .onAppear { vm.onFinish = onFinish }
        .task { runTutorialChecks() }
    }

    private func scene(_ step: TutorialStep, _ space: DesignSpace) -> some View {
        ZStack(alignment: .topLeading) {
            background(space)
            TutorialAngkot(show: step.show, space: space)
            if step.show.contains(.onPavement) { TutorialPavement(space: space) }
            TutorialHUD(show: step.show, clock: step.clock, space: space)
            label(step, space)
            if step.show.contains(.stealBar) { StealBar(progress: vm.fill, space: space) }
            if step.show.contains(.suspicion) { SuspicionBar(lit: vm.spotted, space: space) }
        }
    }

    // the first scene uses the menu's road, the rest use the kerbside one
    private func background(_ space: DesignSpace) -> some View {
        Image(vm.index == 0 ? "menu_road" : "tut_road").resizable().scaledToFill()
            .frame(width: space.px(DesignSpace.screen.width),
                   height: space.px(DesignSpace.screen.height))
            .position(x: space.x(DesignSpace.screen.width / 2),
                      y: space.y(DesignSpace.screen.height / 2))
    }

    private func label(_ step: TutorialStep, _ space: DesignSpace) -> some View {
        place(Tut.label.offsetBy(dx: 0, dy: step.labelY), space) {
            Text("Tutorials")
                .font(.skranji(space.px(Tut.labelSize), bold: false))
                .foregroundStyle(Ink.soft)
                .fixedSize()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func card(_ step: TutorialStep, _ space: DesignSpace) -> some View {
        TutorialCard(text: step.text,
                     nextTitle: vm.nextTitle,
                     space: space,
                     onSkip: vm.skip,
                     onNext: vm.next)
            .frame(width: space.px(DesignSpace.screen.width),
                   height: space.px(DesignSpace.screen.height), alignment: .topLeading)
            .offset(x: space.px(Tut.cardX), y: space.px(step.cardY))
            .position(x: space.x(DesignSpace.screen.width / 2),
                      y: space.y(DesignSpace.screen.height / 2))
    }
}

private func runTutorialChecks() {
    #if DEBUG
    assert(abs(Tut.angkot.midX - (DesignSpace.screen.width / 2 - 0.34)) < 0.01)
    assert(abs(Tut.bar.midX - DesignSpace.screen.width / 2) < 0.01)
    assert(Tut.bar.maxY == DesignSpace.screen.height - 20, "bar sits 20 up from the bottom")

    let steps = TutorialStep.all
    assert(steps.count == 5)
    assert(steps[0].show == [.onPavement], "first scene keeps him out on the pavement")
    assert(steps[1].show.contains(.seatGhosts), "second scene offers him the empty seats")
    assert(steps.dropFirst(2).allSatisfy { $0.show.contains(.onBoard) })
    assert(steps.last!.show.isSuperset(of: [.stealBar, .suspicion, .awareness]),
           "last scene shows all three bars")
    assert(!steps.last!.countsSuspicion, "and its suspicion bar stays grey")
    assert(steps.filter(\.countsSuspicion).count == 1, "only one scene fills it")
    assert(steps.allSatisfy { !$0.show.contains(.hotKanan) || !$0.show.contains(.hotKiriB) },
           "only one passenger is lit at a time")
    assert(steps.filter { $0.show.contains(.alarm) }.count == 1, "clock only panics once")

    // three slots and it wraps, so it can never read past full
    var lit = 0
    for _ in 0..<12 { lit = (lit + 1) % (Tut.slots + 1); assert(lit <= Tut.slots) }

    let span = CGFloat(Tut.slots) * Tut.slot.width + CGFloat(Tut.slots - 1) * Tut.slotGap
    assert(Tut.slotX + span <= Tut.suspOutline.maxX, "slots have to fit inside their box")
    #endif
}

#Preview(traits: .landscapeLeft) { TutorialView {} }
