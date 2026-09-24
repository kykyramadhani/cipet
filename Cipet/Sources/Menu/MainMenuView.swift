import SwiftUI

enum Menu {
    static let space = "menu"   // the slider drag reads its x in this coordinate space

    static let road   = CGRect(x: -1, y: -1, width: 876, height: 403)
    static let angkot = CGRect(x: 80, y: 94, width: 317, height: 301.03949)

    static let headline         = CGRect(x: 445, y: 173, width: 342, height: 52)
    static let headlineSize:    CGFloat = 48
    static let headlineTrack:   CGFloat = -1.8467
    static let headlineOutline: CGFloat = 4
    static let headlineSlack:   CGFloat = 24   // room so the outline doesnt get clipped

    // the frame is the svg, the tap target is the node underneath it
    static let button    = CGRect(x: 496, y: 262, width: 220, height: 60)
    static let buttonArt = CGRect(x: 493.696, y: 259.984, width: 224.554, height: 65.0165)
    static let playSize: CGFloat = 40

    static let infoIcon = CGRect(x: 760.5405, y: 14.9815, width: 38.1716, height: 37.7695)
    static let gearIcon = CGRect(x: 811.469,  y: 15.505,  width: 39.1459, height: 38.7179)
}

struct MainMenuView: View {
    let onPlay: () -> Void

    @State private var settingsShown = false

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                Color.white
                place(Menu.road, space) { Image("menu_road").resizable() }
                place(Menu.angkot, space) { AngkotColored(group: Menu.angkot, space: space) }
                headline(space)
                playButton(space)
                icons(space)

                if settingsShown {
                    SettingsPanel(shown: $settingsShown, space: space).transition(.opacity)
                }
            }
            .coordinateSpace(name: Menu.space)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
    }

    private func headline(_ space: DesignSpace) -> some View {
        place(Menu.headline.insetBy(dx: -Menu.headlineSlack, dy: -Menu.headlineSlack), space) {
            OutlinedText(string: "Ready to Steal?",
                         font: .skranji(space.px(Menu.headlineSize)),
                         fill: Ink.pale,
                         thickness: space.px(Menu.headlineOutline),
                         tracking: space.px(Menu.headlineTrack))
        }
    }

    private func playButton(_ space: DesignSpace) -> some View {
        place(Menu.buttonArt, space) {
            Button(action: onPlay) {
                ZStack {
                    Image("menu_play_button").resizable()
                    Text("Play")
                        .font(.skranji(space.px(Menu.playSize), bold: false))
                        .foregroundStyle(Ink.soft)
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

#Preview(traits: .landscapeLeft) { MainMenuView {} }
