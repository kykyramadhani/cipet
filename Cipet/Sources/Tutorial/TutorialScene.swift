import SwiftUI

// the angkot and everybody in it
struct TutorialAngkot: View {
    let show: TutorialStep.Show
    let space: DesignSpace

    var body: some View {
        Group {
            art("loading_angkot_wheel",    Tut.wheel)
            art("tut_angkot_interior",     Tut.interior)
            art("loading_angkot_exterior", Tut.exterior)
            cast
        }
    }

    @ViewBuilder private var cast: some View {
        if show.contains(.kid) { art("tut_bocah", Tut.bocah) }
        art("tut_kiri_a", Tut.kiriA)

        if show.contains(.seatGhosts) {
            ForEach(Tut.ghosts.indices, id: \.self) { i in
                art("loading_pencipet", Tut.ghosts[i]).opacity(Tut.ghostFade)
            }
        }

        art(show.contains(.hotKiriB) ? "tut_kiri_b_hot" : "tut_kiri_b", Tut.kiriB)
        art("tut_sopir", Tut.sopir)
        art(show.contains(.hotKanan) ? "tut_kanan_hot" : "tut_kanan", Tut.kanan)

        if show.contains(.onBoard) { art("loading_pencipet", Tut.seated) }
        if show.contains(.awareness) {
            ForEach(Tut.aware.indices, id: \.self) { i in
                AwarenessBar(index: i, space: space)
            }
        }
    }

    private func art(_ name: String, _ r: CGRect) -> some View {
        place(Tut.inAngkot(r), space) { Image(name).resizable() }
    }
}

// thief waiting at the kerb before he gets on, with his speech bubble
struct TutorialPavement: View {
    let space: DesignSpace

    var body: some View {
        Group {
            place(Tut.outside, space) { Image("loading_pencipet").resizable() }
            place(Tut.bubble,  space) { Image("tut_bubble").resizable() }
            place(Tut.bubbleText, space) {
                Text("This is you!")
                    .font(.skranji(space.px(Tut.bubbleSize), bold: false))
                    .foregroundStyle(.black)
                    .fixedSize()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

struct TutorialHUD: View {
    let show: TutorialStep.Show
    let clock: String
    let space: DesignSpace

    var body: some View {
        Group {
            panel("tut_panel_wallet", Tut.walletPanel) {
                Image("tut_wallet").resizable()
                    .frame(width: space.px(Tut.walletIcon), height: space.px(Tut.walletIcon))
                Text("00").font(.skranji(space.px(Tut.hudSize), bold: false))
                    .foregroundStyle(.black)
            }
            panel(show.contains(.alarm) ? "tut_panel_alert" : "tut_panel_clock", Tut.clockPanel) {
                Image("tut_clock").resizable()
                    .frame(width: space.px(Tut.clockIcon), height: space.px(Tut.clockIcon))
                Text(clock).font(.skranji(space.px(Tut.hudSize), bold: false))
                    .foregroundStyle(Ink.soft)
            }
        }
    }

    private func panel<C: View>(_ name: String, _ r: CGRect,
                                @ViewBuilder _ content: () -> C) -> some View {
        let off = Tut.bleed(r.size, Tut.panelArt, Tut.panelNudge)
        return place(r, space) {
            ZStack {
                Image(name).resizable()
                    .frame(width: space.px(Tut.panelArt.width),
                           height: space.px(Tut.panelArt.height))
                    .offset(x: space.px(off.width), y: space.px(off.height))
                HStack(spacing: space.px(Tut.hudGap)) { content() }
            }
        }
    }
}
