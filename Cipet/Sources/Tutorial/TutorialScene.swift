import SwiftUI

// the angkot and everybody in it
struct TutorialAngkot: View {
    let show: TutorialStep.Show
    let space: DesignSpace
    /// pick-victim reuses this with its own spots, the tutorial just takes the defaults
    var ghostSeats: [CGRect] = Tut.ghosts
    var thiefAt: CGRect = Tut.seated
    var hot: Seating.Person? = nil
    /// a constant, not a fresh deal — this view rebuilds every tick and re-rolling here
    /// swapped the cast about 60 times a second, which is what made a scene flicker.
    var cast: Arrangement = .fixed
    /// bars over the idle passengers, keyed by who they belong to
    var aware: [Seating.Person: CGFloat] = [:]

    var body: some View {
        Group {
            art("loading_angkot_wheel",    Tut.wheel)
            art("tut_angkot_interior",     Tut.interior)
            art("loading_angkot_exterior", Tut.exterior)
            people
        }
    }

    @ViewBuilder private var people: some View {
        if show.contains(.kid) { passenger(.kid) }
        passenger(.farRight)

        if show.contains(.seatGhosts) {
            ForEach(ghostSeats.indices, id: \.self) { i in
                art("loading_pencipet", ghostSeats[i]).opacity(Tut.ghostFade)
            }
        }

        passenger(.farLeft)
        art("tut_sopir", Tut.sopir)
        passenger(.near)

        if show.contains(.onBoard) { art("loading_pencipet", thiefAt) }
        if show.contains(.awareness) {
            ForEach(Tut.aware.indices, id: \.self) { i in
                AwarenessBar(index: i, level: Tut.awareLevel[i], space: space)
            }
        }
        ForEach(Array(aware.keys), id: \.self) { who in
            AwarenessBar(box: Seating.awareSlot(who), level: aware[who] ?? 0, space: space)
        }
    }

    // picking somebody never changes who they are. the flat cast have a yellow version of
    // their own drawing to swap to, the animated ones keep their frames and get a ring.
    @ViewBuilder private func passenger(_ v: Seating.Person) -> some View {
        let who = cast.who(v)
        let ring: Color? = hot == v ? Ink.yellow : nil

        if let clip = who.clip {
            place(Tut.inAngkot(Clips.box(over: Seating.spot(v))), space) {
                FrameAnimation(clip: clip, ring: ring, ringWidth: space.px(2))
            }
        } else if ring != nil, let yellow = who.hotArt {
            art(yellow, Seating.spot(v))
        } else {
            place(Tut.inAngkot(Seating.spot(v)), space) {
                Sprite(name: who.art, ring: ring, ringWidth: space.px(2))
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
