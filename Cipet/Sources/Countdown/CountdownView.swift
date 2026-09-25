import SwiftUI

enum Countdown {
    static let road = CGRect(x: 0, y: 0, width: 874, height: 402)

    // the angkot group is 455.891 x 440 at y 0, only its x changes between the frames.
    // it's the yellow one, the same drawing the menu and the loading screen pull up in —
    // which is what AngkotColored already is, so the round card borrows it rather than
    // stacking the layers again.
    static let group = CGSize(width: 455.891, height: 440)

    static let readyX: CGFloat = -295   // parked off to the left while the round card is up

    /// where the angkot has got to on each beat. it brakes rather than sliding evenly, and
    /// by "1" its basically parked in the middle where it stays for Start and Steal Time.
    static let vanXs: [CGFloat] = [-128, 27, 173, 209, 209]

    static let banner     = CGRect(x: 0, y: 109, width: 874, height: 184)
    static let dots       = CGRect(x: -100.003, y: -366.998, width: 1074.986, height: 918.275)
    // the round card's banner is yellow, the counting ones are grey, dots a shade lighter either way
    static let bannerGrey = Color(red: 169 / 255, green: 169 / 255, blue: 169 / 255)
    static let dotsGrey   = Color(red: 221 / 255, green: 221 / 255, blue: 221 / 255)
    static let labelInk   = Color(red:  24 / 255, green:  23 / 255, blue:  23 / 255)
    static let roundSize:  CGFloat = 100
    static let countSize:  CGFloat = 120
    static let roundNudge: CGFloat = 25.5   // "Round #1" isnt centred in the banner, the numbers are

    static let labels = ["3", "2", "1", "Start", ""]
    static let steal = labels.count - 1   // the last beat swaps the banner for the van's sign
    static let tick: Double = 1.0   // seconds per number
    static let hold: Double = 0.7   // how long Steal Time sits there before the round starts
    /// the round card used to wait on a Start button. it shows itself for this long instead,
    /// so Play drops you straight into "Round #1" and the count that follows it.
    static let cardHold: Double = 1.0
    /// from the first number to handing over to the round
    static let total: Double = Double(labels.count - 1) * tick + hold

    // the last beat: a halftone starburst over the parked angkot with the words on top.
    // the star is bigger than the screen, so it bleeds off the top and bottom.
    static let star         = CGRect(x: 37, y: -79, width: 800, height: 560)
    static let stealCentre  = CGPoint(x: 436.61, y: 201.26)
    static let stealSize:    CGFloat = 120
    static let stealOutline: CGFloat = 9
    static let stealGap:     CGFloat = -77.8   // stacked words, pulled back over skranjis own line box
    /// the widest a line of the sign is allowed to get. STEAL measures 367 here, so english
    /// never scales — it's a long translation that has to come down to keep the star's margin.
    static let stealWide:    CGFloat = 600

    /// one scale for the whole lockup, taken off its widest line so both words stay the same
    /// size. the gap and the outline are tuned to stealSize, so they ride the scale too.
    static func stealScale(_ words: [String]) -> CGFloat {
        let widest = words.map { GlyphLine($0, size: stealSize, bold: true).box.width }.max() ?? 0
        return widest > stealWide ? stealWide / widest : 1
    }

    static func vanX(_ step: Int) -> CGFloat { vanXs[step] }
}

struct CountdownView: View {
    let round: Int
    let onStart: () -> Void
    let onHome: () -> Void

    @State private var vm = CountdownViewModel()
    private let ticker = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                place(Countdown.road, space) { Image("menu_road").resizable() }
                angkot(space)
                if vm.stealing { stealSign(space) }
                if !vm.stealing { place(Countdown.banner, space) { banner(space) } }
                pauseButton(space)
                if vm.paused {
                    PausedCard(space: space, onResume: vm.resume, onHome: onHome)
                }
            }
            .coordinateSpace(name: Menu.space)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
        .onReceive(ticker) { _ in vm.tick(1.0 / 60) }
        .onAppear { vm.onStart = onStart; vm.round = round }
        .task { runCountdownChecks(); runCountdownModelChecks() }
    }

    private func angkot(_ space: DesignSpace) -> some View {
        let van = CGRect(x: vm.vanX, y: 0,
                         width: Countdown.group.width, height: Countdown.group.height)
        return place(van, space) { AngkotColored(group: van, space: space) }
            .animation(.linear(duration: Countdown.tick), value: vm.step)
    }

    private func stealSign(_ space: DesignSpace) -> some View {
        let words = [t("STEAL"), t("TIME")]
        let k = Countdown.stealScale(words)
        return Group {
            place(Countdown.star, space) { Image("star_burst").resizable() }
            VStack(spacing: space.px(Countdown.stealGap * k)) {
                stealWord(words[0], k, space)
                stealWord(words[1], k, space)
            }
            .position(x: space.x(Countdown.stealCentre.x), y: space.y(Countdown.stealCentre.y))
        }
    }

    private func stealWord(_ word: String, _ k: CGFloat, _ space: DesignSpace) -> some View {
        OutlinedText(string: word,
                     font: .skranji(space.px(Countdown.stealSize * k)),
                     fill: Ink.snow,
                     thickness: space.px(Countdown.stealOutline * k))
    }

    /// coloured strip with the halftone bleeding out of it, clipped, word on top
    private func banner(_ space: DesignSpace) -> some View {
        (vm.waiting ? Ink.yellow : Countdown.bannerGrey)
            .overlay {
                Image("round_dots").renderingMode(.template).resizable()
                    .foregroundStyle(vm.waiting ? Ink.glow : Countdown.dotsGrey)
                    .frame(width: space.px(Countdown.dots.width),
                           height: space.px(Countdown.dots.height))
                    .position(x: space.px(Countdown.dots.midX), y: space.px(Countdown.dots.midY))
            }
            .clipped()
            .overlay { label(space) }
    }

    private func label(_ space: DesignSpace) -> some View {
        Text(vm.label)
            .font(.skranji(space.px(vm.labelSize)))
            .foregroundStyle(Countdown.labelInk)
            .contentTransition(.identity)
            .transaction { $0.animation = nil }   // never cross-fade a number thats changing
            .offset(x: vm.waiting ? space.px(Countdown.roundNudge) : 0)
    }

    /// the round is pausable from the very first card, and it looks the same here as it
    /// does on the pick stage and in the round itself
    private func pauseButton(_ space: DesignSpace) -> some View {
        place(Pick.pauseArt, space) {
            Button { vm.pause() } label: { Image("pv_pause").resizable() }
                .buttonStyle(PressStyle())
        }
    }
}

private func runCountdownChecks() {
    #if DEBUG
    assert(Countdown.vanXs.count == Countdown.labels.count, "one van position per beat")
    // it only ever drives forwards, and it has stopped by the time Start shows
    assert(zip(Countdown.vanXs, Countdown.vanXs.dropFirst()).allSatisfy { $0 <= $1 })
    assert(Countdown.vanXs[Countdown.steal] == Countdown.vanXs[Countdown.steal - 1],
           "the angkot is already parked when Steal Time comes up")
    assert(Countdown.labels[Countdown.steal - 1] == "Start")
    assert(abs(Countdown.total - 4.7) < 0.001, "3-2-1-Start on the tick, then Steal Time holds")

    // the card's van is AngkotColored at this group's width, which is what puts its wheels
    // on the design's 7.125 and its body on 455 x 425
    // the design's own layer rects are rounded to whole pixels, so these are within a
    // tenth of a unit rather than exact
    let k = Countdown.group.width / AngkotColored.box.width
    assert(abs(AngkotColored.tyre.minY * k - 7.125) < 0.1, "wheels sit where the design has them")
    assert(abs(AngkotColored.body.width * k - 455) < 1 && abs(AngkotColored.body.height * k - 425) < 1,
           "and the body fills the group the way the design does")

    // the starburst is centred on the screen and hangs off it top and bottom
    assert(abs(Countdown.star.midX - DesignSpace.screen.width / 2) < 0.5)
    assert(abs(Countdown.star.midY - DesignSpace.screen.height / 2) < 0.5)
    assert(Countdown.star.minY < 0 && Countdown.star.maxY > DesignSpace.screen.height)
    assert(abs(Countdown.stealCentre.y - DesignSpace.screen.height / 2) < 1, "words sit dead centre")
    #endif
}

#Preview(traits: .landscapeLeft) { CountdownView(round: 1, onStart: {}, onHome: {}) }
