import SwiftUI

enum Jail {
    static let dots  = CGRect(x: -100.003, y: -257.998, width: 1074.986, height: 918.275)
    static let thief = CGRect(x: 337.9, y: 94, width: 198.8, height: 278.1)

    // the cage is all flat bars: a light one with a darker stripe down its leading edge
    static let barWide:   CGFloat = 20
    static let barStripe: CGFloat = 5.556
    static let stripeIn:  CGFloat = 14.44
    static let bars = 10
    static let barGap: CGFloat = 75
    static let railsY: [CGFloat] = [87, 293]
    static let barGrey    = Color(red: 161 / 255, green: 161 / 255, blue: 161 / 255)
    static let stripeGrey = Color(red: 115 / 255, green: 115 / 255, blue: 115 / 255)

    static let sign     = CGRect(x: 277, y: 32, width: 320, height: 100)
    static let signArt  = CGRect(x: 272.39, y: 27.83, width: 327.414, height: 110.169)
    static let signText = CGPoint(x: 324, y: 46)
    static let signSize: CGFloat = 72

    // snappy: the cage drops, and only once it has landed does the word come down
    static let barFall: Double = 0.34
    static let signIn:  Double = 0.22
    static let signRise: CGFloat = 70     // how far above its resting place the word starts
}

// the cage comes down first, then JAILED. the order is driven by the task below, not by
// two animations racing each other.
struct JailScreen: View {
    let space: DesignSpace
    let onDone: () -> Void

    @State private var caged = false
    @State private var signed = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Ink.red.ignoresSafeArea()
            halftone
            place(Jail.thief, space) { Image("loading_pencipet").resizable() }
            cage.offset(y: caged ? 0 : -space.px(DesignSpace.screen.height))
            if signed { sign }
        }
        .frame(width: space.px(DesignSpace.screen.width),
               height: space.px(DesignSpace.screen.height))
        .contentShape(Rectangle())
        .onTapGesture { if signed { onDone() } }
        .task {
            withAnimation(.easeOut(duration: Jail.barFall)) { caged = true }
            try? await Task.sleep(for: .seconds(Jail.barFall))
            Audio.shared.play(.failed)
            withAnimation(.easeOut(duration: Jail.signIn)) { signed = true }
        }
    }

    private var halftone: some View {
        Image("round_dots").renderingMode(.template).resizable()
            .foregroundStyle(Ink.redGlow)
            .frame(width: space.px(Jail.dots.width), height: space.px(Jail.dots.height))
            .position(x: space.x(Jail.dots.midX), y: space.y(Jail.dots.midY))
    }

    private var cage: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<Jail.bars, id: \.self) { i in
                let x = -0.5 + CGFloat(i) * (Jail.barWide + Jail.barGap)
                bar(CGRect(x: x, y: 0, width: Jail.barWide, height: DesignSpace.screen.height),
                    stripe: CGRect(x: x + Jail.stripeIn, y: 0,
                                   width: Jail.barStripe, height: DesignSpace.screen.height))
            }
            ForEach(Jail.railsY, id: \.self) { y in
                bar(CGRect(x: 0.5, y: y, width: DesignSpace.screen.width, height: Jail.barWide),
                    stripe: CGRect(x: 0.5, y: y, width: DesignSpace.screen.width,
                                   height: Jail.barStripe))
            }
        }
    }

    private func bar(_ body: CGRect, stripe: CGRect) -> some View {
        Group {
            place(body, space) { Jail.barGrey }
            place(stripe, space) { Jail.stripeGrey }
        }
    }

    private var sign: some View {
        Group {
            place(Jail.signArt, space) { Image("jailed_frame").resizable() }
            Text("JAILED")
                .font(.skranji(space.px(Jail.signSize), bold: false))
                .foregroundStyle(Ink.soft)
                .fixedSize()
                .position(x: space.x(Jail.signText.x + 113), y: space.y(Jail.signText.y + 36))
        }
        .offset(y: signed ? 0 : -space.px(Jail.signRise))
        .opacity(signed ? 1 : 0)
    }
}

func runJailChecks() {
    #if DEBUG
    // the cage spans the screen, and the word only starts after the bars have landed
    let span = CGFloat(Jail.bars) * Jail.barWide + CGFloat(Jail.bars - 1) * Jail.barGap
    assert(abs(span - (DesignSpace.screen.width + 1)) < 1, "the bars have to cover the width")
    assert(Jail.signIn < Jail.barFall, "the word is the quicker of the two")
    assert(Jail.stripeIn + Jail.barStripe <= Jail.barWide, "the stripe sits inside its bar")
    assert(Jail.railsY.allSatisfy { $0 + Jail.barWide < DesignSpace.screen.height })
    #endif
}
