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
    /// greys out the driver and the kid, for when you're picking a target and they're off limits
    var dimFixed = false
    /// what the animated passengers are up to, which picks their animation
    var moods: [Seating.Person: Mood] = [:]
    var paused = false
    /// the yellow body, while you're stealing
    var colored = false

    var body: some View {
        Group {
            art("loading_angkot_wheel",    Tut.wheel)
            art("tut_angkot_interior",     Tut.interior)
            if colored { art("steal_angkot_exterior", Tut.exteriorColored) }
            else { art("loading_angkot_exterior", Tut.exterior) }
            people
        }
    }

    @ViewBuilder private var people: some View {
        if show.contains(.kid) { art("tut_bocah", Tut.bocah).colorMultiply(fixedTint) }
        ForEach(Seating.benches[0], id: \.self) { passenger($0) }

        if show.contains(.seatGhosts) {
            ForEach(ghostSeats.indices, id: \.self) { i in
                art("loading_pencipet", ghostSeats[i]).opacity(Tut.ghostFade)
            }
        }

        art("tut_sopir", Tut.sopir).colorMultiply(fixedTint)
        ForEach(Seating.benches[1], id: \.self) { passenger($0) }

        if show.contains(.onBoard) { art("loading_pencipet", thiefAt) }
        ForEach(Array(aware.keys), id: \.self) { who in
            AwarenessBar(box: Seating.awareSlot(who), level: aware[who] ?? 0, space: space)
        }
    }

    private var fixedTint: Color { dimFixed ? Ink.grey : .white }

    // picking somebody never changes who they are. the flat cast have a yellow version of
    // their own drawing to swap to, the animated ones keep their frames and get a ring.
    @ViewBuilder private func passenger(_ v: Seating.Person) -> some View {
        if let who = cast.who(v) {
            let ring: Color? = hot == v ? Ink.yellow : nil

            if let moves = who.moves {
                place(Tut.inAngkot(Clips.box(over: Seating.spot(v))), space) {
                    RiderActor(moves: moves, mood: moods[v] ?? .calm, paused: paused,
                               ring: ring, ringWidth: space.px(2))
                }
            } else if ring != nil, let yellow = who.hotArt {
                art(yellow, Seating.spot(v))
            } else {
                place(Tut.inAngkot(Seating.spot(v)), space) {
                    Sprite(name: who.art, ring: ring, ringWidth: space.px(2))
                }
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
                Text(t("This is you!"))
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
    /// the cooldown draws the clock again over its red wash, without the wallet
    var clockOnly = false
    /// the last few seconds of the round, which is a whole different panel
    var low = false

    /// swells on the second and springs back down, so the clock has a pulse
    @State private var beating = false

    private var alarm: Bool { low }

    var body: some View {
        Group {
            if !clockOnly {
                panel("tut_panel_wallet", Tut.walletPanel) {
                    Image("tut_wallet").resizable()
                        .frame(width: space.px(Tut.walletIcon), height: space.px(Tut.walletIcon))
                    Text("00").font(.skranji(space.px(Tut.hudSize), bold: false))
                        .foregroundStyle(.black)
                }
            }
            panel(alarm ? "tut_panel_alarm" : "tut_panel_clock", Tut.clockPanel,
                  scale: beating ? Tut.alarmBeat : 1) {
                Image("tut_clock").resizable()
                    .frame(width: space.px(Tut.clockIcon), height: space.px(Tut.clockIcon))
                Text(clock).font(.skranji(space.px(Tut.hudSize), bold: false))
                    .foregroundStyle(alarm ? Ink.snow : Ink.soft)
                    .contentTransition(.identity)
                    .transaction { $0.animation = nil }   // never cross-fade a ticking number
            }
            .onChange(of: clock) { _, _ in thump() }
            .onChange(of: alarm) { _, on in if on { thump() } else { beating = false } }
        }
    }

    /// jump to the bigger size on the tick with no animation, then spring back — a beat,
    /// rather than the slow in-and-out an animated swell would give
    private func thump() {
        guard alarm else { return }
        beating = true
        withAnimation(.spring(response: Tut.alarmSpring, dampingFraction: Tut.alarmBounce)) {
            beating = false
        }
    }

    private func panel<C: View>(_ name: String, _ r: CGRect, scale: CGFloat = 1,
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
            // a render-time scale, so the beat never moves the panel off its mark
            .scaleEffect(scale)
        }
    }
}
