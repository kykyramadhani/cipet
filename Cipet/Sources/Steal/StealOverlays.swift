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

            line(t("Stop for"), Cooldown.stop, Cooldown.lineSize, .white,
                 Cooldown.edge, Cooldown.lineStroke)
            line("\(count)", Cooldown.count, Cooldown.countSize, Ink.snow,
                 Ink.red, Cooldown.countStroke)
            line(t("You almost get caught!"), Cooldown.note, Cooldown.lineSize, .white,
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

// pause card. the model holds whatever screen it's over still, this is just the menu on
// top of it — and the same settings panel the main menu puts up, so sound and language
// can be changed without leaving the round.
struct PausedCard: View {
    let space: DesignSpace
    let onResume: () -> Void
    let onHome: () -> Void

    @State private var settingsShown = false

    private static let card  = CGRect(x: 300, y: 92, width: 274, height: 190)
    private static let title: CGFloat = 34
    private static let row   = CGSize(width: 214, height: 38)
    private static let rowGap: CGFloat = 10
    private static let rowSize: CGFloat = 22

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()

            VStack(spacing: space.px(Self.rowGap)) {
                Text(t("Paused"))
                    .font(.skranji(space.px(Self.title)))
                    .foregroundStyle(Ink.black)
                    .padding(.bottom, space.px(2))
                button(t("Resume"), filled: true, action: onResume)
                button(t("Main Menu"), filled: false, action: onHome)
                button(t("Settings"), filled: false) {
                    withAnimation(.easeInOut(duration: 0.2)) { settingsShown = true }
                }
            }
            .padding(space.px(16))
            .frame(width: space.px(Self.card.width))
            .background(Ink.paper, in: RoundedRectangle(cornerRadius: space.px(14)))
            .overlay(RoundedRectangle(cornerRadius: space.px(14))
                .stroke(.black, lineWidth: space.px(5)))
            .position(x: space.x(DesignSpace.screen.width / 2),
                      y: space.y(DesignSpace.screen.height / 2))

            if settingsShown {
                SettingsPanel(shown: $settingsShown, space: space).transition(.opacity)
            }
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


// the mugshot on the succeed card: the mark, still sat where you left them. it isn't a
// sprite on a swatch — the design frames a piece of the angkot itself, bench and window
// and all, cropped round whoever you just robbed, so the card shows the person rather
// than a picture of one.
struct VictimPortrait: View {
    let victim: Seating.Person
    let cast: Arrangement
    let space: DesignSpace

    /// the design's frame, 160 x 297. its brush-stroke border is drawn over this separately.
    static let box    = CGSize(width: 160, height: 297)
    static let radius: CGFloat = 8

    /// how wide a slice of the angkot shows through, in the angkot's own units. the height
    /// follows from the frame's shape, so there is only ever one number to tune: set it so
    /// the mark fills the frame the way the design has them, about two thirds across.
    static let cropWidth: CGFloat = 78
    static var cropHeight: CGFloat { cropWidth * box.height / box.width }
    static let drop: CGFloat = 0.07   // how far below centre the mark sits

    var body: some View {
        let seat = Seating.spot(victim)
        let s = space.px(Self.box.width) / Self.cropWidth
        // the top-left of the window, in the angkot group's coordinates
        let ox = seat.midX - Self.cropWidth / 2
        let oy = seat.midY - Self.drop * Self.cropHeight - Self.cropHeight / 2

        ZStack(alignment: .topLeading) {
            Ink.pale
            layer("loading_angkot_wheel",    Tut.wheel,    ox, oy, s)
            layer("tut_angkot_interior",     Tut.interior, ox, oy, s)
            layer("loading_angkot_exterior", Tut.exterior, ox, oy, s)
            layer(art, mark(seat), ox, oy, s)
        }
        .frame(width: space.px(Self.box.width), height: space.px(Self.box.height),
               alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: space.px(Self.radius)))
    }

    /// them idle, in their own frames, drawn from the same bigger box the angkot uses
    private var art: String { cast.who(victim)?.art ?? "" }

    private func mark(_ seat: CGRect) -> CGRect { Clips.box(over: seat) }

    private func layer(_ name: String, _ r: CGRect,
                       _ ox: CGFloat, _ oy: CGFloat, _ s: CGFloat) -> some View {
        Image(name).resizable()
            .frame(width: r.width * s, height: r.height * s)
            .offset(x: (r.minX - ox) * s, y: (r.minY - oy) * s)
    }
}

func runPortraitChecks() {
    #if DEBUG
    // the portrait is the design's frame exactly, and sits inside the card
    assert(VictimPortrait.box == SucceedCard.frame.size)
    assert(SucceedCard.cardArt.contains(SucceedCard.frame))

    // the window keeps the frame's shape, so nothing in the angkot comes out stretched
    assert(abs(VictimPortrait.cropHeight / VictimPortrait.cropWidth
               - VictimPortrait.box.height / VictimPortrait.box.width) < 0.001)

    // every mark can be framed, whole, and each one lands in a different part of the angkot
    var seen: Set<String> = []
    for v in Seating.dealt {
        let seat = Seating.spot(v)
        let ox = seat.midX - VictimPortrait.cropWidth / 2
        let oy = seat.midY - VictimPortrait.drop * VictimPortrait.cropHeight
                 - VictimPortrait.cropHeight / 2
        assert(seat.minX >= ox && seat.maxX <= ox + VictimPortrait.cropWidth,
               "\(v) has to fit across their own portrait")
        assert(seat.minY >= oy && seat.maxY <= oy + VictimPortrait.cropHeight,
               "head and feet both")
        seen.insert("\(Int(ox)),\(Int(oy))")
    }
    assert(seen.count == Seating.dealt.count, "each mark gets their own crop")
    #endif
}

// what you get for pulling it off: the mark, still sat where you left them, the takings, and
// where to go next. it sits straight on the scene, the design doesnt dim what's behind it.
struct SucceedCard: View {
    let remaining: String
    let value: Int
    let victim: Seating.Person
    let cast: Arrangement
    let space: DesignSpace
    let onNext: () -> Void
    let onEnd: () -> Void

    static let cardArt = CGRect(x: 163.652, y: 28.756, width: 546.659, height: 346.242)
    /// where the mark's portrait goes, and the brush-stroke frame drawn over it
    static let frame    = CGRect(x: 187, y: 53, width: 160, height: 297)
    static let frameArt = CGRect(x: 181, y: 48.429, width: 170.339, height: 306.292)
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
            place(Self.frame, space) { VictimPortrait(victim: victim, cast: cast, space: space) }
            place(Self.frameArt, space) { Image("succeed_frame").resizable() }
            place(Self.title, space) {
                Text(t("Succeed!"))
                    .font(.skranji(space.px(60)))
                    .foregroundStyle(.black)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            let lines = [(t("Remaining time"), remaining), (t("Item value"), "Rp \(value)k")]
            ForEach(lines.indices, id: \.self) { i in
                statRow(lines[i].0, lines[i].1, 22, 24, Ink.stone,
                        CGRect(x: Self.title.minX, y: Self.rows[i], width: Self.title.width,
                               height: Self.rowH), space)
            }
            statRow(t("Total Item value"), "Rp \(value)k", 22, 24, .black,
                    CGRect(x: Self.title.minX, y: Self.totalY, width: Self.title.width,
                           height: Self.rowH), space)
            artButton(t("End Game"), "succeed_red", Self.endBox, Self.endArt, space, onEnd)
            artButton(t("Next Round"), "succeed_yellow", Self.nextBox, Self.nextArt, space, onNext)
        }
    }
}
