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

    /// the white sign the word sits on. the art bleeds past it by this much.
    static let sign     = CGRect(x: 277, y: 32, width: 320, height: 100)
    static let failed   = CGRect(x: 277, y: 44, width: 320, height: 100)
    static let signBleed = CGRect(x: -4.61, y: -4.17, width: 7.414, height: 10.169)
    static let signSize: CGFloat = 72
    /// the widest the word may get before it runs into the frame art's border. JAILED is
    /// 226 so english never scales; a longer one comes down to keep JAILED's own margin.
    static let signWide: CGFloat = 270

    static func signScale(_ word: String) -> CGFloat {
        let w = GlyphLine(word, size: signSize).box.width
        return w > signWide ? signWide / w : 1
    }

    // snappy: the cage drops, and only once it has landed does the word come down
    static let barFall: Double = 0.34
    static let signIn:  Double = 0.22
    static let signRise:   CGFloat = 70   // how far above its resting place the word starts
    static let failedRise: CGFloat = 75   // Failed comes in from 31 above the screen
}

// the cage comes down first, then JAILED. the order is driven by the task below, not by
// two animations racing each other. out of time is the same screen with no cage and Failed.
struct JailScreen: View {
    let space: DesignSpace
    var jailed = true
    let onDone: () -> Void

    @State private var caged = false
    @State private var signed = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Ink.red.ignoresSafeArea()
            Halftone(tint: Ink.redGlow, space: space)
            place(Jail.thief, space) { Image("loading_pencipet").resizable() }
            if jailed {
                Cage(space: space).offset(y: caged ? 0 : -space.px(DesignSpace.screen.height))
            }
            if signed {
                JailSign(word: jailed ? "JAILED" : "Failed", box: jailed ? Jail.sign : Jail.failed,
                         space: space)
                    .transition(.opacity.combined(with: .offset(
                        y: -space.px(jailed ? Jail.signRise : Jail.failedRise))))
            }
        }
        .frame(width: space.px(DesignSpace.screen.width),
               height: space.px(DesignSpace.screen.height))
        .contentShape(Rectangle())
        .onTapGesture { if signed { onDone() } }
        .task {
            if jailed {
                withAnimation(.easeOut(duration: Jail.barFall)) { caged = true }
                try? await Task.sleep(for: .seconds(Jail.barFall))
            }
            Audio.shared.play(.failed)
            withAnimation(.easeOut(duration: Jail.signIn)) { signed = true }
        }
    }
}

/// the red and yellow screens' dot pattern, bigger than the screen and tinted to suit
struct Halftone: View {
    let tint: Color
    let space: DesignSpace

    var body: some View {
        Image("round_dots").renderingMode(.template).resizable()
            .foregroundStyle(tint)
            .frame(width: space.px(Jail.dots.width), height: space.px(Jail.dots.height))
            .position(x: space.x(Jail.dots.midX), y: space.y(Jail.dots.midY))
    }
}

struct Cage: View {
    let space: DesignSpace

    var body: some View {
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
}

/// JAILED or Failed on its white sign, centred in `box`. `word` is the english; it's
/// translated here and shrunk to fit if the translation runs longer than the plate.
struct JailSign: View {
    let word: String
    let box: CGRect
    let space: DesignSpace

    var body: some View {
        let art = CGRect(x: box.minX + Jail.signBleed.minX, y: box.minY + Jail.signBleed.minY,
                         width: box.width + Jail.signBleed.width,
                         height: box.height + Jail.signBleed.height)
        let said = t(word)
        Group {
            place(art, space) { Image("jailed_frame").resizable() }
            Text(said)
                .font(.skranji(space.px(Jail.signSize * Jail.signScale(said)), bold: false))
                .foregroundStyle(Ink.soft)
                .fixedSize()
                .position(x: space.x(box.midX), y: space.y(box.midY))
        }
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
    // the sign art is the 327x110 export, and Failed starts at -31 like the design's first frame
    assert(abs(Jail.sign.width + Jail.signBleed.width - 327.414) < 0.01)
    assert(Jail.failed.minY - Jail.failedRise == -31)
    #endif
}
