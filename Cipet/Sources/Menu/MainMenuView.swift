import SwiftUI

enum Menu {
    static let space = "menu"   // the slider drag reads its x in this coordinate space

    static let road   = CGRect(x: -1, y: -1, width: 876, height: 403)
    static let angkot = CGRect(x: 80, y: 94, width: 317, height: 301.03949)

    // the menu comes in two heights. with nothing to show, Play sits on its own in the
    // middle of the right hand side; once there's a record to open, the headline and Play
    // move up to make room for the second button under them.
    static let headline      = CGRect(x: 445, y: 173, width: 342, height: 52)
    static let headlineTall  = CGRect(x: 454, y:  86, width: 342, height: 52)
    static let headlineSize:    CGFloat = 48
    static let headlineTrack:   CGFloat = -1.8467
    static let headlineOutline: CGFloat = 4
    static let headlineSlack:   CGFloat = 24   // room so the outline doesnt get clipped

    // the frame is the svg, the tap target is the node underneath it
    static let button     = CGRect(x: 496, y: 262, width: 220, height: 60)
    static let playTall   = CGRect(x: 505, y: 175, width: 220, height: 60)
    static let recordTall = CGRect(x: 505, y: 256, width: 220, height: 60)
    static let playSize: CGFloat = 40

    /// the svg is drawn a little larger than its tap target and hangs off it evenly
    static let buttonBleed = CGSize(width: 2.304, height: 2.016)
    static let buttonArtSize = CGSize(width: 224.554, height: 65.0165)

    static func art(_ node: CGRect) -> CGRect {
        CGRect(x: node.minX - buttonBleed.width, y: node.minY - buttonBleed.height,
               width: buttonArtSize.width, height: buttonArtSize.height)
    }

    // the two corner icons are one row: equal squares, a fixed gap, the same artwork frame
    // around each glyph. the svg is drawn a shade larger than the square and hangs off it
    // unevenly, which is why the art rect is derived rather than written down twice.
    static let iconRow   = CGPoint(x: 763, y: 16)
    static let iconSide:  CGFloat = 33
    static let iconGap:   CGFloat = 16
    static let iconBleed = CGSize(width: 1.3756, height: 0.9603)   // top left only
    static let iconArtSize = CGSize(width: 35.9904, height: 35.6112)

    static func icon(_ i: Int) -> CGRect {
        CGRect(x: iconRow.x + CGFloat(i) * (iconSide + iconGap) - iconBleed.width,
               y: iconRow.y - iconBleed.height,
               width: iconArtSize.width, height: iconArtSize.height)
    }

    static var infoIcon: CGRect { icon(0) }
    static var gearIcon: CGRect { icon(1) }
}

struct MainMenuView: View {
    let onPlay: () -> Void

    @State private var settingsShown = false
    @State private var recordShown = false

    /// nothing has been finished yet, so there is nothing to open and the menu stays short
    private var hasRecord: Bool { Record.shared.hasAny }

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                Color.white
                place(Menu.road, space) { Image("menu_road").resizable() }
                place(Menu.angkot, space) { AngkotColored(group: Menu.angkot, space: space) }
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
            }
            .task { runMenuChecks() }
            .coordinateSpace(name: Menu.space)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
    }

    private func headline(_ space: DesignSpace) -> some View {
        let box = hasRecord ? Menu.headlineTall : Menu.headline
        return place(box.insetBy(dx: -Menu.headlineSlack, dy: -Menu.headlineSlack), space) {
            OutlinedText(string: t("Ready to Steal?"),
                         font: .skranji(space.px(Menu.headlineSize)),
                         fill: Ink.pale,
                         thickness: space.px(Menu.headlineOutline),
                         tracking: space.px(Menu.headlineTrack))
        }
    }

    private func playButton(_ space: DesignSpace) -> some View {
        button(hasRecord ? Menu.playTall : Menu.button,
               art: "menu_play_button", title: t("Play"), space: space, action: onPlay)
    }

    /// only once there is a record to look at. the store is what decides, so it comes back
    /// on its own the moment a round is banked.
    private func recordButton(_ space: DesignSpace) -> some View {
        button(Menu.recordTall, art: "menu_record_button", title: t("Record"), space: space) {
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
            place(Menu.infoIcon, space) { Image("menu_icon_info").resizable() }
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

    // Play is where the eye goes, so it holds its spot whether or not Record is under it
    assert(Menu.playTall.size == Menu.button.size && Menu.recordTall.size == Menu.button.size)
    assert(Menu.recordTall.minY > Menu.playTall.maxY, "Record hangs below Play")
    assert(Menu.headlineTall.maxY < Menu.playTall.minY, "and the headline clears both")
    #endif
}

#Preview(traits: .landscapeLeft) { MainMenuView {} }
