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
    /// the thief when he's animated (stealing). he's drawn at his seat's depth, not on top
    /// of everything: `thiefAt` says which row that is.
    var thief: AnyView? = nil

    var body: some View {
        Group {
            art("loading_angkot_wheel",    Tut.wheel)
            art("tut_angkot_interior",     Tut.interior)
            // the driver sits in his cab under the body panel, the way the design layers him
            place(Tut.inAngkot(Clips.box(over: Tut.sopir, ink: Clips.driverInk)), space) {
                Image("Driver-0000").resizable()
            }
            .colorMultiply(fixedTint)
            if colored { art("steal_angkot_exterior", Tut.exteriorColored) }
            else { art("loading_angkot_exterior", Tut.exterior) }
            people
        }
    }

    // painted back to front: the far bench (and the kid beside it) sits further from us than
    // the near bench, so anyone on the near bench covers anyone behind them, the thief
    // included. each bar goes in with its own passenger, at their depth.
    @ViewBuilder private var people: some View {
        if show.contains(.kid), cast.kid {
            place(Tut.inAngkot(Clips.box(over: Tut.bocah)), space) {
                RiderActor(moves: Rider.kid.moves, mood: .alert, paused: paused)
            }
            .colorMultiply(fixedTint)
            bar(.kid)
        }
        row(0)
        row(1)
    }

    @ViewBuilder private func row(_ bench: Int) -> some View {
        let seats = Seating.benches[bench]
        ForEach(seats, id: \.self) { passenger($0) }
        if show.contains(.seatGhosts) {
            ForEach(ghostSeats.filter { Seating.bench(of: $0) == bench }, id: \.self) { spot in
                sitting(spot).opacity(Tut.ghostFade)
            }
        }
        if Seating.bench(of: thiefAt) == bench {
            if let thief { thief } else if show.contains(.onBoard) { sitting(thiefAt) }
        }
        ForEach(seats, id: \.self) { bar($0) }
    }

    @ViewBuilder private func bar(_ who: Seating.Person) -> some View {
        if let level = aware[who] {
            AwarenessBar(box: Seating.awareSlot(who), level: level, space: space)
        }
    }

    /// the thief sat still at a seat: facing us on the far bench, his back to us on the near one
    @ViewBuilder private func sitting(_ spot: CGRect) -> some View {
        if Seating.bench(of: spot) == 1 {
            place(Tut.inAngkot(Clips.box(over: spot)), space) {
                Sprite(name: Clips.behindIdle(left: false).frame(0))
            }
        } else {
            art("loading_pencipet", spot)
        }
    }

    private var fixedTint: Color { dimFixed ? Ink.grey : .white }

    // picking somebody never changes who they are: they keep their own frames and get a ring
    @ViewBuilder private func passenger(_ v: Seating.Person) -> some View {
        if let who = cast.who(v) {
            place(Tut.inAngkot(Clips.box(over: Seating.spot(v))), space) {
                RiderActor(moves: who.moves, mood: moods[v] ?? .alert, paused: paused,
                           ring: hot == v ? Ink.yellow : nil, ringWidth: space.px(2))
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
    /// items taken over every round finished so far
    var items = 0

    /// swells on the second and springs back down, so the clock has a pulse
    @State private var beating = false

    private var alarm: Bool { low }

    var body: some View {
        Group {
            if !clockOnly {
                panel("tut_panel_wallet", Tut.walletPanel) {
                    Image("tut_wallet").resizable()
                        .frame(width: space.px(Tut.walletIcon), height: space.px(Tut.walletIcon))
                    // sized for two digits and left aligned: more digits run on to the right,
                    // the icon never shifts
                    Text("\(items)").font(.skranji(space.px(Tut.hudSize), bold: false))
                        .foregroundStyle(.black)
                        .fixedSize()
                        .frame(width: space.px(Tut.itemsWidth), alignment: .leading)
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
