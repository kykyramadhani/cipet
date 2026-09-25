import SwiftUI

enum Menu {
    static let space = "menu"   // the slider drag reads its x in this coordinate space

    static let road = CGRect(x: -1, y: -1, width: 876, height: 403)

    /// 396:763. the van fills the left of the screen and runs off three of its edges — it is
    /// the same three layer drawing the loading screen uses, just far bigger and sat well
    /// outside the canvas, so AngkotColored scales the lot from this one box.
    static let angkot = CGRect(x: -269, y: 16, width: 499.0204, height: 473.8954)

    /// he stands on the kerb behind the lockup, cut off by the top of the screen, and steps
    /// aside a little once there is a second button to make room for
    static let standup = CGSize(width: 97.338, height: 138.108)
    static let standupY: CGFloat = -20
    static let standupX:     CGFloat = 576
    static let standupXTall: CGFloat = 611

    // MARK: the lockup — the game's name over the question
    // the whole thing lifts when Record joins Play underneath it. both lines move together,
    // so the pair of centres is all either state needs.
    static let titleAt     = CGPoint(x: 437, y: 145)
    static let titleAtTall = CGPoint(x: 437, y:  94)
    static let titleSize:    CGFloat = 80
    static let titleOutline: CGFloat = 10
    static let titleBox    = CGSize(width: 232, height: 140)

    static let headlineAt     = CGPoint(x: 437.5, y: 215)
    static let headlineAtTall = CGPoint(x: 437.5, y: 164)
    static let headlineSize:    CGFloat = 40
    static let headlineTrack:   CGFloat = -1.8467
    static let headlineOutline: CGFloat = 4
    static let headlineBox    = CGSize(width: 253, height: 52)

    // MARK: buttons. the frame is the svg, the tap target is the node underneath it
    static let button     = CGRect(x: 317, y: 257, width: 240, height: 60)
    static let playTall   = CGRect(x: 316, y: 219, width: 240, height: 60)
    static let recordTall = CGRect(x: 316, y: 291, width: 240, height: 60)
    static let playSize: CGFloat = 40

    /// the svg is drawn a little larger than its tap target and hangs off its top left
    static let buttonBleed = CGSize(width: 2.3184, height: 2.022)
    static let buttonArtSize = CGSize(width: 244.315, height: 65.0214)

    static func art(_ node: CGRect) -> CGRect {
        CGRect(x: node.minX - buttonBleed.width, y: node.minY - buttonBleed.height,
               width: buttonArtSize.width, height: buttonArtSize.height)
    }

    // MARK: the two corner icons, one row of matching squares
    static let iconRow  = CGPoint(x: 746, y: 16)
    static let iconSide: CGFloat = 40
    static let iconGap:  CGFloat = 12

    /// both glyphs were drawn for a 33 box and the row is bigger than that now, so the art
    /// and its overhang scale together rather than being written down twice at a new size
    private static let iconDrawn: CGFloat = 33
    static var iconScale: CGFloat { iconSide / iconDrawn }
    static var iconBleed: CGSize {
        CGSize(width: 1.3756 * iconScale, height: 0.9603 * iconScale)
    }
    static var iconArtSize: CGSize {
        CGSize(width: 35.9904 * iconScale, height: 35.6112 * iconScale)
    }

    static func icon(_ i: Int) -> CGRect {
        CGRect(x: iconRow.x + CGFloat(i) * (iconSide + iconGap) - iconBleed.width,
               y: iconRow.y - iconBleed.height,
               width: iconArtSize.width, height: iconArtSize.height)
    }

    static var infoIcon: CGRect { icon(0) }
    static var gearIcon: CGRect { icon(1) }

    /// how much slack a stroked word needs round its box so drawingGroup cannot clip the ring
    static func slack(_ box: CGSize, _ thickness: CGFloat) -> CGSize {
        CGSize(width: box.width + 8 * thickness, height: box.height + 8 * thickness)
    }
}

struct MainMenuView: View {
    let onPlay: () -> Void

    @State private var settingsShown = false
    @State private var recordShown = false
    @State private var instructionShown = false

    /// nothing has been finished yet, so there is nothing to open and the menu stays short
    private var hasRecord: Bool { Record.shared.hasAny }

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                Color.white
                place(Menu.road, space) { Image("menu_road").resizable() }
                place(Menu.angkot, space) { AngkotColored(group: Menu.angkot, space: space) }
                standup(space)
                title(space)
                headline(space)
                playButton(space)
                if hasRecord { recordButton(space) }
                icons(space)

                if settingsShown {
                    SettingsPanel(shown: $settingsShown, space: space).transition(.opacity)
                }
                if recordShown {
                    RecordPanel(shown: $recordShown, space: space).transition(.opacity)
                }
                if instructionShown {
                    InstructionPanel(shown: $instructionShown, space: space)
                        .transition(.opacity)
                }
            }
            .task { runMenuChecks(); runGlyphChecks() }
            .coordinateSpace(name: Menu.space)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
    }

    /// the design draws him as vector art, but it is the same thief the loading screen
    /// stands on the kerb — ten megabytes of traced halftone against a sprite already in
    /// the bundle, so this is the sprite
    private func standup(_ space: DesignSpace) -> some View {
        let x = hasRecord ? Menu.standupXTall : Menu.standupX
        return place(CGRect(x: x, y: Menu.standupY,
                            width: Menu.standup.width, height: Menu.standup.height), space) {
            Image("loading_pencipet").resizable()
        }
    }

    private func title(_ space: DesignSpace) -> some View {
        outlined("CIPET", at: hasRecord ? Menu.titleAtTall : Menu.titleAt,
                 box: Menu.titleBox, size: Menu.titleSize, fill: Ink.yellow,
                 thickness: Menu.titleOutline, twoRings: true, space: space)
    }

    /// the tagline is set in the regular weight and set tight, and its outline is a real
    /// stroke on the glyphs — skranji's little mitred spikes are the tell, and the ring of
    /// offset copies CIPET uses rounds them off
    private func headline(_ space: DesignSpace) -> some View {
        let at = hasRecord ? Menu.headlineAtTall : Menu.headlineAt
        let room = Menu.slack(Menu.headlineBox, Menu.headlineOutline)
        return place(CGRect(x: at.x - room.width / 2, y: at.y - room.height / 2,
                            width: room.width, height: room.height), space) {
            StrokedText(string: t("Ready to Steal?"), size: Menu.headlineSize,
                        fill: Ink.snow, rim: Ink.black, width: Menu.headlineOutline,
                        scale: space.scale, tracking: Menu.headlineTrack)
        }
    }

    /// OutlinedText sizes itself and flattens into one layer, so the box here only has to be
    /// roomy enough that the ring is not cropped off at the edges
    private func outlined(_ string: String, at centre: CGPoint, box: CGSize, size: CGFloat,
                          fill: Color, thickness: CGFloat, tracking: CGFloat = 0,
                          twoRings: Bool = false, space: DesignSpace) -> some View {
        let room = Menu.slack(box, thickness)
        return place(CGRect(x: centre.x - room.width / 2, y: centre.y - room.height / 2,
                            width: room.width, height: room.height), space) {
            OutlinedText(string: string,
                         font: .skranji(space.px(size)),
                         fill: fill,
                         thickness: space.px(thickness),
                         tracking: space.px(tracking),
                         twoRings: twoRings)
        }
    }

    private func playButton(_ space: DesignSpace) -> some View {
        button(hasRecord ? Menu.playTall : Menu.button,
               art: "menu_btn", title: t("Play"), space: space, action: onPlay)
    }

    /// only once there is a record to look at. the store is what decides, so it comes back
    /// on its own the moment a round is banked.
    private func recordButton(_ space: DesignSpace) -> some View {
        button(Menu.recordTall, art: "menu_btn_off", title: t("Record"), space: space) {
            withAnimation(.easeInOut(duration: 0.2)) { recordShown = true }
        }
    }

    private func button(_ node: CGRect, art: String, title: String,
                        space: DesignSpace, action: @escaping () -> Void) -> some View {
        place(Menu.art(node), space) {
            Button(action: action) {
                ZStack {
                    Image(art).resizable()
                    Text(title)
                        .font(.skranji(space.px(Menu.playSize), bold: false))
                        .foregroundStyle(Ink.soft)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, space.px(14))
                }
            }
            .buttonStyle(PressStyle())
        }
    }

    private func icons(_ space: DesignSpace) -> some View {
        Group {
            place(Menu.infoIcon, space) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { instructionShown = true }
                } label: { Image("menu_icon_info").resizable() }
                    .buttonStyle(PressStyle())
            }
            place(Menu.gearIcon, space) {
                Button { settingsShown = true } label: { Image("menu_icon_gear").resizable() }
                    .buttonStyle(PressStyle())
            }
        }
    }
}

func runMenuChecks() {
    #if DEBUG
    // the icons are a row of matching squares, not two lumps that happen to sit near each
    // other — which is how the gear ended up a circle beside a rounded square once already
    assert(Menu.infoIcon.size == Menu.gearIcon.size, "one frame, two glyphs")
    assert(abs(Menu.gearIcon.minX - Menu.infoIcon.minX - (Menu.iconSide + Menu.iconGap)) < 0.01)
    assert(Menu.infoIcon.minY == Menu.gearIcon.minY, "and they sit on the same line")
    assert(Menu.infoIcon.maxX < Menu.gearIcon.minX, "with daylight between them")
    assert(Menu.gearIcon.maxX < DesignSpace.screen.width, "the gear stays on screen")
    // the glyphs keep their own shape at whatever size the row is
    assert(abs(Menu.iconArtSize.width / Menu.iconArtSize.height - 35.9904 / 35.6112) < 0.0001)

    // the van is the loading screen's drawing at another size, so its box has to keep the
    // proportions AngkotColored scales everything else from
    assert(abs(Menu.angkot.width / Menu.angkot.height
               - AngkotColored.box.width / AngkotColored.box.height) < 0.001)
    assert(Menu.angkot.minX < 0 && Menu.angkot.maxY > DesignSpace.screen.height,
           "it runs off the left and the bottom, and is clipped there")

    // both states: the lockup sits above its buttons, and nothing lands on anything else
    for (title, head, play) in [(Menu.titleAt, Menu.headlineAt, Menu.button),
                                (Menu.titleAtTall, Menu.headlineAtTall, Menu.playTall)] {
        assert(title.y < head.y, "the name is over the question")
        assert(head.y < play.midY, "and the question over the buttons")
        assert(abs(title.x - head.x) < 1, "the two lines share a centre")
    }
    // lifting the lockup moves both its lines by the same amount, so it stays a lockup
    assert(abs((Menu.titleAt.y - Menu.titleAtTall.y)
               - (Menu.headlineAt.y - Menu.headlineAtTall.y)) < 0.01)

    // Play keeps its size and its centre whether or not Record is under it
    assert(Menu.playTall.size == Menu.button.size && Menu.recordTall.size == Menu.button.size)
    assert(abs(Menu.playTall.midX - Menu.button.midX) < 2, "and near enough its place")
    assert(Menu.recordTall.minY > Menu.playTall.maxY, "Record hangs below Play")
    assert(Menu.recordTall.maxY < DesignSpace.screen.height, "and still fits on the screen")

    // the artwork covers the tap target it is drawn for, with the overhang on the top left
    for node in [Menu.button, Menu.playTall, Menu.recordTall] {
        assert(Menu.art(node).contains(node), "the plate covers its button")
    }

    // the words fit their plates at full size, in both languages, so neither is riding
    // minimumScaleFactor to stay on the button
    let room = Menu.button.width - 2 * 14
    for word in ["Play", "Record"] {
        for copy in [word, Indonesian.table[word] ?? word] {
            let w = GlyphLine(copy, size: Menu.playSize).box.width
            assert(w <= room, "\(copy) is \(Int(w)) wide against \(Int(room)) of plate")
        }
    }
    // and both lines of the lockup come out about as wide as the design's boxes for them
    assert(abs(GlyphLine("CIPET", size: Menu.titleSize, bold: true).box.width
               - Menu.titleBox.width) < 24, "CIPET has drifted off its box")
    let tagline = GlyphLine("Ready to Steal?", size: Menu.headlineSize,
                            tracking: Menu.headlineTrack).box.width
    assert(abs(tagline - Menu.headlineBox.width) < 12,
           "the tagline is \(Int(tagline)) against the design's \(Int(Menu.headlineBox.width))")

    // he stands clear of the lockup in both states, and is cut off by the top of the screen
    assert(Menu.standupY < 0)
    for x in [Menu.standupX, Menu.standupXTall] {
        assert(x > Menu.titleAt.x + Menu.titleBox.width / 2, "he is off to the side of it")
        assert(x + Menu.standup.width < Menu.infoIcon.minX, "and clear of the icons")
    }
    #endif
}

#Preview(traits: .landscapeLeft) { MainMenuView {} }
