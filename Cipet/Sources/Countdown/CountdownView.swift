import SwiftUI

enum Countdown {
    static let road = CGRect(x: 0, y: 0, width: 874, height: 402)

    // the angkot group is 455.891 x 440 at y 0, only its x changes between the frames
    static let group    = CGSize(width: 455.891, height: 440)
    static let exterior = CGRect(x: 0,     y: 0,     width: 455.891, height: 425.875)
    static let wheel    = CGRect(x: 0,     y: 14.13, width: 455.891, height: 425.875)
    static let roof     = CGRect(x: 3.528, y: 3.534, width: 448.475, height: 418.812)

    static let readyX: CGFloat = -295   // parked while the round card is up
    static let firstX: CGFloat = -128   // on "3"
    static let lastX:  CGFloat =  209   // on "Start"

    static let banner     = CGRect(x: 0, y: 109, width: 874, height: 184)
    static let dots       = CGRect(x: -100.003, y: -366.998, width: 1074.986, height: 918.275)
    static let bannerGrey = Color(red: 169 / 255, green: 169 / 255, blue: 169 / 255)
    static let labelInk   = Color(red:  24 / 255, green:  23 / 255, blue:  23 / 255)
    static let roundSize:  CGFloat = 100
    static let countSize:  CGFloat = 120
    static let roundNudge: CGFloat = 25.5   // "Round #1" isnt centred in the banner, the numbers are

    static let buttonArt = CGRect(x: 337.696, y: 312.984, width: 224.554, height: 65.0165)
    static let startSize: CGFloat = 48

    static let labels = ["3", "2", "1", "Start"]
    static let tick: Double = 1.0   // seconds per number
    static let hold: Double = 0.7   // beat on "Start" before the round begins

    static func vanX(_ step: Int) -> CGFloat {
        firstX + (lastX - firstX) * CGFloat(step) / CGFloat(labels.count - 1)
    }
}

struct CountdownView: View {
    let onStart: () -> Void

    @State private var vm = CountdownViewModel()

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                place(Countdown.road, space) { Image("menu_road").resizable() }
                angkot(space)
                place(Countdown.banner, space) { banner(space) }
                if vm.waiting { startButton(space) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
        .onAppear { vm.onStart = onStart }
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
        }
        .animation(.linear(duration: Countdown.tick), value: vm.step)
    }

    private func layer(_ name: String, _ r: CGRect, _ space: DesignSpace) -> some View {
        Image(name).resizable()
            .frame(width: space.px(r.width), height: space.px(r.height))
            .offset(x: space.px(r.minX), y: space.px(r.minY))
    }

    /// grey strip with the halftone bleeding out of it, clipped, word on top
    private func banner(_ space: DesignSpace) -> some View {
        Countdown.bannerGrey
            .overlay {
                Image("round_dots").resizable()
                    .frame(width: space.px(Countdown.dots.width),
                           height: space.px(Countdown.dots.height))
                    .position(x: space.px(Countdown.dots.midX), y: space.px(Countdown.dots.midY))
            }
            .clipped()
            .overlay { label(space) }
    }

    private func label(_ space: DesignSpace) -> some View {
        // one round for now so the number is literal. pass it in when rounds stack up.
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
    assert(Countdown.vanX(0) == Countdown.firstX, "must open where the \"3\" frame puts the angkot")
    assert(Countdown.vanX(Countdown.labels.count - 1) == Countdown.lastX, "and end on the \"Start\" one")
    assert(Countdown.labels.last == "Start")
    #endif
}

#Preview(traits: .landscapeLeft) { CountdownView {} }
