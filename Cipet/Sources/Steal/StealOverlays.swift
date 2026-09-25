import SwiftUI

enum Cooldown {
    // an ellipse of red centred on the screen, see-through in the middle and solid at the
    // edges. the box is bigger than the screen, so past the ellipse it's all edge colour.
    static let wash   = CGRect(x: 437 - 505.8, y: 201 - 232.6, width: 1011.6, height: 465.2)
    static let middle = Color(red: 211 / 255, green: 68 / 255, blue: 53 / 255).opacity(0.72)
    static let edge   = Color(red: 192 / 255, green: 57 / 255, blue: 43 / 255)
    static let blur: CGFloat = 4

    /// the wash thins out as the count runs down
    static func strength(_ count: Int) -> Double {
        switch count {
        case 3...: return 1
        case 2:    return 0.8
        default:   return 0.4
        }
    }

    // one box per line, straight off the design. the line height is skranji's own
    // "normal" (ascent + descent: 54.336 at 40, 108.672 at 80), stacked with no gaps, so
    // nothing here is left to swiftui's line spacing.
    static let stop  = CGRect(x: 363.5, y: 125,     width: 147, height: 54.336)
    static let count = CGRect(x: 414.5, y: 179.336, width: 45,  height: 108.672)
    static let note  = CGRect(x: 230,   y: 288.008, width: 414, height: 54.336)
    static let lineSize:  CGFloat = 40
    static let countSize: CGFloat = 80
    // both outside the letter, mitred
    static let lineStroke:  CGFloat = 4
    static let countStroke: CGFloat = 12
}

// stops play for a few seconds after somebody clocks you. the scene underneath is blurred
// by StealView, and the clock is drawn again on top of all this so it stays sharp.
struct PenaltyOverlay: View {
    let count: Int
    let space: DesignSpace

    var body: some View {
        ZStack(alignment: .topLeading) {
            place(Cooldown.wash, space) {
                EllipticalGradient(colors: [Cooldown.middle, Cooldown.edge],
                                   startRadiusFraction: 0, endRadiusFraction: 0.5)
            }
            .opacity(Cooldown.strength(count))
            .animation(.easeOut(duration: 0.25), value: count)

            line("Stop for", Cooldown.stop, Cooldown.lineSize, .white,
                 Cooldown.edge, Cooldown.lineStroke)
            line("\(count)", Cooldown.count, Cooldown.countSize, Ink.snow,
                 Ink.red, Cooldown.countStroke)
            line("You almost get caught!", Cooldown.note, Cooldown.lineSize, .white,
                 Cooldown.edge, Cooldown.lineStroke)
        }
        .allowsHitTesting(false)
    }

    private func line(_ text: String, _ box: CGRect, _ size: CGFloat,
                      _ fill: Color, _ rim: Color, _ stroke: CGFloat) -> some View {
        place(box, space) {
            StrokedText(string: text, size: size, fill: fill, rim: rim,
                        width: stroke, scale: space.scale)
        }
        .transaction { $0.animation = nil }   // a number thats changing never cross-fades
    }
}

func runCooldownChecks() {
    #if DEBUG
    // the three lines are stacked edge to edge and centred on the screen, like the design
    for box in [Cooldown.stop, Cooldown.count, Cooldown.note] {
        assert(abs(box.midX - DesignSpace.screen.width / 2) < 0.01, "every line is centred")
    }
    assert(abs(Cooldown.stop.maxY - Cooldown.count.minY) < 0.001
           && abs(Cooldown.count.maxY - Cooldown.note.minY) < 0.001,
           "no gaps between the lines, the line boxes do the spacing")
    assert(abs(Cooldown.note.maxY - Cooldown.stop.minY - 217) < 0.5, "the column is 217 tall")

    // the boxes are skranji's own line height, so the glyph line fills them exactly
    let forty = GlyphLine("Stop for", size: Cooldown.lineSize)
    let eighty = GlyphLine("3", size: Cooldown.countSize)
    assert(abs(forty.box.height - Cooldown.stop.height) < 0.01)
    assert(abs(eighty.box.height - Cooldown.count.height) < 0.01)
    assert(abs(forty.box.width - Cooldown.stop.width) < 1, "and as wide as the design's")
    assert(!forty.path.isEmpty, "skranji has to actually be loaded for the outlines")

    // the wash covers the screen and eases off 3 -> 2 -> 1
    let screen = CGRect(origin: .zero, size: DesignSpace.screen)
    assert(Cooldown.wash.contains(screen))
    assert(Cooldown.strength(3) == 1 && Cooldown.strength(2) == 0.8 && Cooldown.strength(1) == 0.4)
    #endif
}

// pause card. the model holds the round still, this is just the menu on top of it.
struct PausedCard: View {
    let space: DesignSpace
    let onResume: () -> Void
    let onHome: () -> Void

    private static let card  = CGRect(x: 300, y: 92, width: 274, height: 190)
    private static let title: CGFloat = 34
    private static let row   = CGSize(width: 214, height: 38)
    private static let rowGap: CGFloat = 10
    private static let rowSize: CGFloat = 22

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()

            VStack(spacing: space.px(Self.rowGap)) {
                Text("Paused")
                    .font(.skranji(space.px(Self.title)))
                    .foregroundStyle(Ink.black)
                    .padding(.bottom, space.px(2))
                button("Resume", filled: true, action: onResume)
                button("Main Menu", filled: false, action: onHome)
                button("Settings", filled: false) {}
            }
            .padding(space.px(16))
            .frame(width: space.px(Self.card.width))
            .background(Ink.paper, in: RoundedRectangle(cornerRadius: space.px(14)))
            .overlay(RoundedRectangle(cornerRadius: space.px(14))
                .stroke(.black, lineWidth: space.px(5)))
            .position(x: space.x(DesignSpace.screen.width / 2),
                      y: space.y(DesignSpace.screen.height / 2))
        }
    }

    private func button(_ title: String, filled: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.skranji(space.px(Self.rowSize), bold: false))
                .foregroundStyle(Ink.black)
                .frame(width: space.px(Self.row.width), height: space.px(Self.row.height))
                .background(filled ? Ink.yellow : Color.white,
                            in: RoundedRectangle(cornerRadius: space.px(9)))
                .overlay(RoundedRectangle(cornerRadius: space.px(9))
                    .stroke(.black, lineWidth: space.px(3)))
        }
        .buttonStyle(PressStyle())
    }
}

// what you get for pulling it off: a snap of the thief in his seat, the takings, and where to
// go next. it sits straight on the scene, the design doesnt dim what's behind it.
struct SucceedCard: View {
    let remaining: String
    let value: Int
    let space: DesignSpace
    let onNext: () -> Void
    let onEnd: () -> Void

    static let cardArt = CGRect(x: 163.652, y: 28.756, width: 546.659, height: 346.242)
    /// the snap of him in his seat, brush-stroke frame and all
    static let snap   = CGRect(x: 181, y: 48.429, width: 170.339, height: 306.292)
    static let title  = CGRect(x: 367, y: 61, width: 320, height: 72)
    static let rows: [CGFloat] = [149, 191.4]      // remaining time, item value
    static let totalY: CGFloat = 249.8
    static let rowH:   CGFloat = 26.4
    static let endBox  = CGRect(x: 367, y: 310, width: 154, height: 40)
    static let nextBox = CGRect(x: 533, y: 310, width: 154, height: 40)
    static let endArt  = CGRect(x: 364.683, y: 307.696, width: 158.75, height: 45.3043)
    static let nextArt = CGRect(x: 530.683, y: 307.696, width: 158.75, height: 45.3043)

    var body: some View {
        ZStack(alignment: .topLeading) {
            place(Self.cardArt, space) { Image("succeed_card").resizable() }
            place(Self.snap, space) { Image("succeed_snap").resizable() }
            place(Self.title, space) {
                Text("Succeed!")
                    .font(.skranji(space.px(60)))
                    .foregroundStyle(.black)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            let lines = [("Remaining time", remaining), ("Item value", "Rp \(value)k")]
            ForEach(lines.indices, id: \.self) { i in
                statRow(lines[i].0, lines[i].1, 22, 24, Ink.stone,
                        CGRect(x: Self.title.minX, y: Self.rows[i], width: Self.title.width,
                               height: Self.rowH), space)
            }
            statRow("Total Item value", "Rp \(value)k", 22, 24, .black,
                    CGRect(x: Self.title.minX, y: Self.totalY, width: Self.title.width,
                           height: Self.rowH), space)
            artButton("End Game", "succeed_red", Self.endBox, Self.endArt, space, onEnd)
            artButton("Next Round", "succeed_yellow", Self.nextBox, Self.nextArt, space, onNext)
        }
    }
}
