import SwiftUI

enum Cog {
    struct Row { let track: CGRect; let knobY: CGFloat }

    static let dim   = Color(red: 34 / 255, green: 33 / 255, blue: 33 / 255)
    static let card  = CGRect(x: 213.658, y: 51.679, width: 440.666, height: 289.331)
    static let close = CGRect(x: 625.62,  y: 39.62,  width: 38.76,   height: 38.76)

    static let title       = CGRect(x: 363, y: 78, width: 139, height: 52)
    static let titleSize:    CGFloat = 40
    static let titleTrack:   CGFloat = -1.5
    static let titleOutline: CGFloat = 3.5

    static let labelSize:  CGFloat = 30
    static let labelTrack: CGFloat = -1.8467
    static let sfxLabel   = CGRect(x: 256, y: 147, width: 43,  height: 41)
    static let musicLabel = CGRect(x: 256, y: 199, width: 69,  height: 41)
    static let langLabel  = CGRect(x: 251, y: 256, width: 116, height: 41)

    static let sfx   = Row(track: CGRect(x: 346, y: 159, width: 259, height: 18.873), knobY: 154)
    static let music = Row(track: CGRect(x: 346, y: 211, width: 259, height: 18.873), knobY: 207)
    static let trackStroke: CGFloat = 3.118
    static let fillDrop:    CGFloat = 1.99   // the fill sits this far below the track top
    static let fillHeight:  CGFloat = 14.9
    static let knobNode  = CGSize(width: 27, height: 24)
    static let knobArt   = CGSize(width: 34.7998, height: 31.7197)
    static let knobNudge = CGSize(width: -1.44, height: -2.36)
    static let grabSlack: CGFloat = 14   // taller than the track so a thumb can catch it

    static let engArt  = CGRect(x: 387.849, y: 260.071, width: 104.412, height: 38.4296)
    static let indArt  = CGRect(x: 501.849, y: 260.071, width: 104.412, height: 38.4296)
    static let engNode = CGRect(x: 389, y: 261, width: 102, height: 36)
    static let indNode = CGRect(x: 503, y: 261, width: 102, height: 36)
    static let langSize: CGFloat = 20

    /// knob's right edge sits on the end of the fill, clamped so it never hangs off either end
    static func knobX(_ value: Double, _ track: CGRect) -> CGFloat {
        min(max(track.minX, track.minX + track.width * value - knobNode.width),
            track.maxX - knobNode.width)
    }
}

struct SettingsPanel: View {
    @Binding var shown: Bool
    let space: DesignSpace

    @State private var vm = SettingsViewModel()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Cog.dim.opacity(0.6).ignoresSafeArea().onTapGesture { close() }

            place(Cog.card, space) { Image("settings_card").resizable() }
            title

            label(t("SFX"),      Cog.sfxLabel)
            label(t("Music"),    Cog.musicLabel)
            label(t("Language"), Cog.langLabel)

            slider(Binding(get: { vm.sfx },   set: { vm.sfx = $0 }),   Cog.sfx)
            slider(Binding(get: { vm.music }, set: { vm.music = $0 }), Cog.music)

            language
            closeButton
        }
        .task { runSettingsChecks() }
    }

    private func close() { withAnimation(.easeInOut(duration: 0.2)) { shown = false } }

    private var title: some View {
        place(Cog.title.insetBy(dx: -20, dy: -20), space) {
            OutlinedText(string: t("Settings"),
                         font: .skranji(space.px(Cog.titleSize)),
                         fill: Ink.pale,
                         thickness: space.px(Cog.titleOutline),
                         tracking: space.px(Cog.titleTrack))
        }
    }

    private func label(_ text: String, _ rect: CGRect) -> some View {
        place(rect, space) {
            Text(text)
                .font(.skranji(space.px(Cog.labelSize), bold: false))
                .tracking(space.px(Cog.labelTrack))
                .foregroundStyle(Ink.black)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // whichever one is on gets the yellow artwork, the other the white one — the two svgs
    // are the same shape, so the pair swaps by which picture each button draws
    private var language: some View {
        Group {
            langButton(.eng, art: Cog.engArt, node: Cog.engNode)
            langButton(.ind, art: Cog.indArt, node: Cog.indNode)
        }
    }

    private func langButton(_ lang: Lang, art: CGRect, node: CGRect) -> some View {
        let on = vm.lang == lang
        return Group {
            place(art, space) {
                Image(on ? "settings_btn_eng" : "settings_btn_ind").resizable()
            }
            place(node, space) {
                Text(lang.label)
                    .font(.skranji(space.px(Cog.langSize), bold: false))
                    .foregroundStyle(on ? Ink.soft : Ink.black)
            }
            // one target over the pair of them, so the word is as tappable as the pill
            place(art, space) {
                Rectangle().fill(.clear).contentShape(Rectangle())
            }
            .onTapGesture {
                guard !on else { return }
                Audio.shared.play(.click)
                vm.lang = lang
            }
        }
    }

    private var closeButton: some View {
        place(Cog.close, space) {
            Button(action: close) { Image("settings_close").resizable() }
                .buttonStyle(PressStyle())
        }
    }

    @ViewBuilder private func slider(_ value: Binding<Double>, _ row: Cog.Row) -> some View {
        let t = row.track
        let fill = CGRect(x: t.minX, y: t.minY + Cog.fillDrop,
                          width: t.width * value.wrappedValue, height: Cog.fillHeight)
        let knob = CGRect(x: Cog.knobX(value.wrappedValue, t) + Cog.knobNudge.width,
                          y: row.knobY + Cog.knobNudge.height,
                          width: Cog.knobArt.width, height: Cog.knobArt.height)

        place(t, space) {
            Capsule().fill(.white)
                .overlay(Capsule().strokeBorder(Ink.black, lineWidth: space.px(Cog.trackStroke)))
        }
        place(fill, space) { Capsule().fill(Ink.yellow) }
        place(knob, space) { Image("settings_knob").resizable() }

        place(t.insetBy(dx: 0, dy: -Cog.grabSlack), space) {
            Rectangle().fill(.clear).contentShape(Rectangle())
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(Menu.space))
                .onChanged { g in
                    let x = (g.location.x - space.ox - space.px(t.minX)) / space.px(t.width)
                    value.wrappedValue = min(1, max(0, x))
                }
        )
    }
}

private func runSettingsChecks() {
    #if DEBUG
    let t = Cog.sfx.track
    assert(abs(Cog.knobX(172.828 / 259, t) - 492) < 0.5, "knob should land on 492 at 66.7%")
    assert(Cog.knobX(0, t) == t.minX, "empty must not hang off the left end")
    assert(abs(Cog.knobX(1, t) - (t.maxX - Cog.knobNode.width)) < 0.001, "full must not hang off the right")
    #endif
}
