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

enum Pause {
    // 382:267. the popup node is 360 x 285 sat a few units left of centre and a little
    // below it; the card artwork is a touch narrower than that node and bleeds past it.
    static let popup = CGRect(x: 251, y: 70, width: 360, height: 285)
    static let card  = CGRect(x: 257.678, y: 67.72, width: 345.668, height: 291.284)

    /// the design dims and blurs the whole round behind the card rather than blacking it out,
    /// so you can still see the angkot you're going back to
    static let dim  = Color(white: 102 / 255).opacity(0.4)
    static let blur: CGFloat = 4

    static let titleAt = CGPoint(x: 431, y: 117)
    static var title: CGRect { CardTitle.box(titleAt) }

    // a column of buttons: two full width, then two half width side by side
    static let wide  = CGSize(width: 240, height: 52)
    static let small = CGSize(width: 112, height: 52)
    static let gap:  CGFloat = 12
    static let left: CGFloat = 311      // the column is centred on the card, the row is not
    static let top:  CGFloat = 159

    static var resume: CGRect { CGRect(origin: CGPoint(x: left, y: top), size: wide) }
    static var home:   CGRect { resume.offsetBy(dx: 0, dy: wide.height + gap) }
    static var info:   CGRect { CGRect(x: left, y: home.maxY + gap,
                                       width: small.width, height: small.height) }
    static var gear:   CGRect { info.offsetBy(dx: small.width + gap, dy: 0) }

    /// both plates are drawn larger than their button and hang off the top left corner by
    /// the same amount, so one number covers all four
    static let plateBleed = CGSize(width: 2.317, height: 2.122)
    static let wideArt  = CGSize(width: 244.745, height: 57.1388)
    static let smallArt = CGSize(width: 117.059, height: 57.1073)

    static func plate(_ node: CGRect, _ art: CGSize) -> CGRect {
        CGRect(x: node.minX - plateBleed.width, y: node.minY - plateBleed.height,
               width: art.width, height: art.height)
    }

    // inside a wide button: a 200 wide row, nudged 3 right of centre, icon then words
    static let rowWidth:  CGFloat = 200
    static let rowNudge:  CGFloat = 3
    static let icon:      CGFloat = 30
    static let iconGap:   CGFloat = 8
    static let labelSize: CGFloat = 28

    // the two glyphs are cropped tight rather than framed, so each sits on its button by
    // its own offset instead of dead centre
    static let infoArt  = CGSize(width: 9.75854, height: 26.8754)
    static let gearArt  = CGSize(width: 29.4923, height: 31.1874)
    static let infoNudge = CGSize(width: -1.117, height: -1.063)
    static let gearNudge = CGSize(width: -0.481, height: -0.369)

    // he leans over the top of the card, cut off by the top of the screen
    static let thief    = CGRect(x: 329.012, y: -84, width: 187.992, height: 179.969)
    static let thiefArt = CGSize(width: 187.992, height: 262.95)   // 163 x 228, to width
    static let thiefTilt: Double = -0.55
}

// pause card. the model holds whatever screen it's over still, this is just the menu on
// top of it — and the same settings panel the main menu puts up, so sound and language
// can be changed without leaving the round, plus the instructions for when you have
// forgotten which bar is which.
struct PausedCard: View {
    let space: DesignSpace
    let onResume: () -> Void
    let onHome: () -> Void

    @State private var settingsShown = false
    @State private var instructionShown = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Pause.dim.ignoresSafeArea()

            // he is behind the card, so only his head and shoulders clear the top of it
            place(Pause.thief, space) {
                Image("loading_pencipet").resizable()
                    .frame(width: space.px(Pause.thiefArt.width),
                           height: space.px(Pause.thiefArt.height))
                    .frame(width: space.px(Pause.thief.width),
                           height: space.px(Pause.thief.height), alignment: .top)
                    .clipped()
                    .rotationEffect(.degrees(Pause.thiefTilt))
            }

            place(Pause.card, space) { Image("pause_card").resizable() }
            title
            wide(Pause.resume, art: "pause_btn", icon: "pause_ic_play",
                 title: t("Resume"), action: onResume)
            wide(Pause.home, art: "pause_btn_off", icon: "pause_ic_home",
                 title: t("Main Menu"), action: onHome)
            small(Pause.info, art: Pause.infoArt, nudge: Pause.infoNudge,
                  icon: "pause_ic_info") {
                withAnimation(.easeInOut(duration: 0.2)) { instructionShown = true }
            }
            small(Pause.gear, art: Pause.gearArt, nudge: Pause.gearNudge,
                  icon: "pause_ic_gear") {
                withAnimation(.easeInOut(duration: 0.2)) { settingsShown = true }
            }

            if settingsShown {
                SettingsPanel(shown: $settingsShown, space: space).transition(.opacity)
            }
            if instructionShown {
                InstructionPanel(shown: $instructionShown, space: space).transition(.opacity)
            }
        }
        .task { runPauseChecks() }
    }

    private var title: some View {
        CardTitle(text: t("Paused"), centre: Pause.titleAt, space: space)
    }

    /// icon and words on one row, laid from the left of a fixed box so Resume and Main Menu
    /// line their icons up with each other however long the words get
    private func wide(_ node: CGRect, art: String, icon: String, title: String,
                      action: @escaping () -> Void) -> some View {
        let row = CGRect(x: node.midX + Pause.rowNudge - Pause.rowWidth / 2,
                         y: node.midY - Pause.icon / 2,
                         width: Pause.rowWidth, height: Pause.icon)
        return place(Pause.plate(node, Pause.wideArt), space) {
            Button(action: action) { Image(art).resizable() }
                .buttonStyle(PressStyle())
        }
        .overlay(alignment: .topLeading) {
            place(row, space) {
                HStack(spacing: space.px(Pause.iconGap)) {
                    Image(icon).resizable()
                        .frame(width: space.px(Pause.icon), height: space.px(Pause.icon))
                    Text(title)
                        .font(.skranji(space.px(Pause.labelSize), bold: false))
                        .foregroundStyle(Ink.black)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func small(_ node: CGRect, art: CGSize, nudge: CGSize, icon: String,
                       action: @escaping () -> Void) -> some View {
        place(Pause.plate(node, Pause.smallArt), space) {
            Button(action: action) {
                ZStack {
                    Image("pause_btn_small").resizable()
                    Image(icon).resizable()
                        .frame(width: space.px(art.width), height: space.px(art.height))
                        .offset(x: space.px(nudge.width + Pause.plateBleed.width
                                            - (Pause.smallArt.width - node.width) / 2),
                                y: space.px(nudge.height + Pause.plateBleed.height
                                            - (Pause.smallArt.height - node.height) / 2))
                }
            }
            .buttonStyle(PressStyle())
        }
    }
}

func runPauseChecks() {
    #if DEBUG
    // the card artwork covers the node it was drawn for, and sits on the screen
    assert(Pause.card.contains(Pause.popup.insetBy(dx: 10, dy: 0)), "the plate covers the popup")
    assert(Pause.card.minY > 0 && Pause.card.maxY < DesignSpace.screen.height)

    // one column: Resume, Main Menu, then the pair, each clear of the last by the gap
    assert(Pause.home.minY - Pause.resume.maxY == Pause.gap)
    assert(Pause.info.minY - Pause.home.maxY == Pause.gap)
    assert(Pause.gear.minX - Pause.info.maxX == Pause.gap)
    assert(Pause.info.minY == Pause.gear.minY, "the pair share a line")
    assert(abs(Pause.resume.midX - Pause.home.midX) < 0.01, "and the wide ones share a centre")

    // everything the player can press is inside the card, and below the title
    let inside = Pause.card.insetBy(dx: 6, dy: 6)
    for box in [Pause.title, Pause.resume, Pause.home, Pause.info, Pause.gear] {
        assert(inside.contains(box), "\(box) has to be on the card")
    }
    assert(Pause.title.maxY <= Pause.resume.minY, "nothing overlaps the word Paused")

    // the pair between them come to the width of the ones above, bar a few units of slack
    // on the right — the row is laid from the left of the column, not centred under it
    assert(2 * Pause.small.width + Pause.gap <= Pause.wide.width)
    assert(2 * Pause.small.width + Pause.gap >= Pause.wide.width - 6)
    assert(Pause.small.height == Pause.wide.height, "and the same height")

    // he is cut off by the top of the screen and hidden by the card below it, so only the
    // band between the two ever shows
    assert(Pause.thief.minY < 0, "his head runs off the top")
    assert(Pause.thief.maxY > Pause.card.minY, "and the card covers the rest of him")
    assert(abs(Pause.thiefArt.height / Pause.thiefArt.width - 228.0 / 163) < 0.01,
           "he keeps his own proportions")
    assert(Pause.thiefArt.height > Pause.thief.height, "the box crops him rather than squashing")
    #endif
}


// the mugshot on the succeed card: the mark, still sat where you left them. it isn't a
// sprite on a swatch — the design frames a piece of the angkot itself, bench and window
// and all, cropped round whoever you just robbed, so the card shows the person rather
// than a picture of one.
struct VictimPortrait: View {
    let victim: Seating.Person
    let cast: Arrangement
    let space: DesignSpace

    /// the design's frame is 160 x 297 with a 12 border, so everything here is that shape
    /// scaled down to the width the card has room for
    static let box    = CGSize(width: 96, height: 178.2)
    static let border: CGFloat = 7.2
    static let radius: CGFloat = 4.8

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
        .overlay(RoundedRectangle(cornerRadius: space.px(Self.radius))
            .strokeBorder(.black, lineWidth: space.px(Self.border)))
    }

    /// the yellow version of their drawing where there is one — the animated faces only
    /// have their own frames, so they show as they are
    private var art: String {
        let who = cast.who(victim)
        return who.hotArt ?? who.art
    }

    /// the animated faces are drawn from a bigger box than the seat, the same way the
    /// angkot draws them, or they come out shrunk inside their own frame
    private func mark(_ seat: CGRect) -> CGRect {
        cast.who(victim).animated ? Clips.box(over: seat) : seat
    }

    private func layer(_ name: String, _ r: CGRect,
                       _ ox: CGFloat, _ oy: CGFloat, _ s: CGFloat) -> some View {
        Image(name).resizable()
            .frame(width: r.width * s, height: r.height * s)
            .offset(x: (r.minX - ox) * s, y: (r.minY - oy) * s)
    }
}

func runPortraitChecks() {
    #if DEBUG
    // the frame keeps the design's 160 x 297 proportions, and its border with them
    assert(abs(VictimPortrait.box.height / VictimPortrait.box.width - 297.0 / 160) < 0.01)
    assert(abs(VictimPortrait.border / VictimPortrait.box.width - 12.0 / 160) < 0.01)
    // and it fits the card it sits in, inside the padding
    assert(VictimPortrait.box.height <= 210 - 2 * 16 + 0.5, "the portrait has to fit the card")

    // the window keeps the frame's shape, so nothing in the angkot comes out stretched
    assert(abs(VictimPortrait.cropHeight / VictimPortrait.cropWidth
               - VictimPortrait.box.height / VictimPortrait.box.width) < 0.001)

    // every mark can be framed, whole, and each one lands in a different part of the angkot
    var seen: Set<String> = []
    for v in Seating.victims {
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
    assert(seen.count == Seating.victims.count, "each mark gets their own crop")
    #endif
}

// what you get for pulling it off. the mark, the takings, and where to go next.
struct SucceedCard: View {
    let remaining: String
    let value: Int
    let victim: Seating.Person
    let cast: Arrangement
    let space: DesignSpace
    let onNext: () -> Void
    let onEnd: () -> Void

    private static let card  = CGSize(width: 430, height: 210)
    private static let title: CGFloat = 40
    private static let row:   CGFloat = 17
    private static let btn   = CGSize(width: 116, height: 30)

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()

            HStack(spacing: space.px(18)) {
                VictimPortrait(victim: victim, cast: cast, space: space)

                VStack(alignment: .leading, spacing: space.px(6)) {
                    Text(t("Succeed!"))
                        .font(.skranji(space.px(Self.title)))
                        .foregroundStyle(Ink.black)
                    line(t("Remaining time"), remaining)
                    line(t("Item value"), "Rp \(value)k")
                    line(t("Total Item value"), "Rp \(value)k")
                    HStack(spacing: space.px(10)) {
                        button(t("End Game"), Ink.redGlow, action: onEnd)
                        button(t("Next Round"), Ink.yellow, action: onNext)
                    }
                    .padding(.top, space.px(4))
                }
            }
            .padding(space.px(16))
            .frame(width: space.px(Self.card.width), alignment: .leading)
            .background(Ink.paper, in: RoundedRectangle(cornerRadius: space.px(12)))
            .overlay(RoundedRectangle(cornerRadius: space.px(12))
                .stroke(.black, lineWidth: space.px(5)))
            .position(x: space.x(DesignSpace.screen.width / 2),
                      y: space.y(DesignSpace.screen.height / 2))
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: space.px(12))
            Text(value)
        }
        .font(.skranji(space.px(Self.row), bold: false))
        .foregroundStyle(Ink.black)
    }

    private func button(_ title: String, _ fill: Color,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.skranji(space.px(15), bold: false))
                .foregroundStyle(Ink.black)
                .frame(width: space.px(Self.btn.width), height: space.px(Self.btn.height))
                .background(fill, in: RoundedRectangle(cornerRadius: space.px(7)))
                .overlay(RoundedRectangle(cornerRadius: space.px(7))
                    .stroke(.black, lineWidth: space.px(2.5)))
        }
        .buttonStyle(PressStyle())
    }
}
