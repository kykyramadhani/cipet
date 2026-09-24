import SwiftUI

enum Countdown {
    static let road = CGRect(x: 0, y: 0, width: 874, height: 402)

    // the angkot group is 455.891 x 440 at y 0, only its x changes between the frames
    static let group    = CGSize(width: 455.891, height: 440)
    static let exterior = CGRect(x: 0,     y: 0,     width: 455.891, height: 425.875)
    static let wheel    = CGRect(x: 0,     y: 14.13, width: 455.891, height: 425.875)
    static let roof     = CGRect(x: 3.528, y: 3.534, width: 448.475, height: 418.812)

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

    static let buttonArt = CGRect(x: 337.696, y: 312.984, width: 224.554, height: 65.0165)
    static let startSize: CGFloat = 48

    static let labels = ["3", "2", "1", "Start", ""]
    static let steal = labels.count - 1   // the last beat swaps the banner for the van's sign
    static let tick: Double = 1.0   // seconds per number
    static let hold: Double = 0.7   // how long Steal Time sits there before the round starts

    // the "Steal Time!" lettering, centred on the angkot group's own coordinates
    static let stealCentre  = CGPoint(x: 229, y: 212)
    static let stealSize:    CGFloat = 120
    static let stealOutline: CGFloat = 9
    static let stealGap:     CGFloat = -77.8   // stacked words, pulled back over skranjis own line box

    static func vanX(_ step: Int) -> CGFloat { vanXs[step] }
}

struct CountdownView: View {
    let round: Int
    let onStart: () -> Void

    @State private var vm = CountdownViewModel()

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                place(Countdown.road, space) { Image("menu_road").resizable() }
                angkot(space)
                if !vm.stealing { place(Countdown.banner, space) { banner(space) } }
                if vm.waiting { startButton(space) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
        .onAppear { vm.onStart = onStart; vm.round = round }
        .task { runCountdownChecks() }
    }

    private func angkot(_ space: DesignSpace) -> some View {
        place(CGRect(x: vm.vanX, y: 0,
                     width: Countdown.group.width, height: Countdown.group.height), space) {
            ZStack(alignment: .topLeading) {
                layer("loading_angkot_exterior", Countdown.exterior, space)
                layer("loading_angkot_wheel",    Countdown.wheel,    space)
                layer("loading_angkot_roof",     Countdown.roof,     space)
            }
            .frame(width: space.px(Countdown.group.width),
                   height: space.px(Countdown.group.height), alignment: .topLeading)
            .overlay(alignment: .topLeading) { if vm.stealing { stealSign(space) } }
        }
        .animation(.linear(duration: Countdown.tick), value: vm.step)
    }

    private func stealSign(_ space: DesignSpace) -> some View {
        VStack(spacing: space.px(Countdown.stealGap)) {
            stealWord("Steal", space)
            stealWord("Time!", space)
        }
        .position(x: space.px(Countdown.stealCentre.x), y: space.px(Countdown.stealCentre.y))
    }

    private func stealWord(_ word: String, _ space: DesignSpace) -> some View {
        OutlinedText(string: word,
                     font: .skranji(space.px(Countdown.stealSize)),
                     fill: Ink.yellow,
                     thickness: space.px(Countdown.stealOutline))
    }

    private func layer(_ name: String, _ r: CGRect, _ space: DesignSpace) -> some View {
        Image(name).resizable()
            .frame(width: space.px(r.width), height: space.px(r.height))
            .offset(x: space.px(r.minX), y: space.px(r.minY))
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

    private func startButton(_ space: DesignSpace) -> some View {
        place(Countdown.buttonArt, space) {
            Button { vm.begin() } label: {
                ZStack {
                    Image("menu_play_button").resizable()
                    Text("Start")
                        .font(.skranji(space.px(Countdown.startSize), bold: false))
                        .foregroundStyle(Ink.soft)
                }
            }
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
    #endif
}

#Preview(traits: .landscapeLeft) { CountdownView(round: 1) {} }
