import SwiftUI

enum Loading {
    static let duration: Double = 2.8   // how long the bar takes to fill
    static let hold:     Double = 0.4   // beat at 100% before we move on

    // the strip along the bottom is menu_road upside down, cropped to the kerb and the
    // tarmac under it. `road` is the slice that shows, `roadArt` is the whole picture behind it.
    static let road    = CGRect(x: 0, y: 338,   width: 874, height: 64)
    static let roadArt = CGRect(x: 0, y: 112.4, width: 874, height: 321.6)

    static let pole    = CGRect(x: 789, y: 237, width: 10, height: 141)
    static let sign    = CGRect(x: 759, y: 202, width: 70.36699, height: 76)
    static let busIcon = CGSize(width: 53.58058, height: 19.69515)
    static let signBlue = Color(red: 13 / 255, green: 102 / 255, blue: 182 / 255)

    static let title        = CGRect(x: 224, y: 96, width: 426, height: 140)
    static let titleSize:    CGFloat = 147.36
    static let titleOutline: CGFloat = 13
    static let titleSlack:   CGFloat = 40   // room so the outline doesnt get clipped

    static let thiefBox   = CGRect(x: 299, y: 21.77316, width: 75.71292, height: 101.33934)
    static let thiefArt   = CGSize(width: 69.20290, height: 96.78771)
    static let thiefAngle: Double = -3.96

    // both corner radii are bigger than half the height so these are capsules
    static let bar       = CGRect(x: 153, y: 268, width: 535, height: 19)
    static let barStroke: CGFloat = 6
    static let fillY:     CGFloat = 270
    static let fillH:     CGFloat = 15

    static let angkot     = CGSize(width: 68.44617, height: 65)
    static let angkotY:    CGFloat = 243
    static let angkotLead: CGFloat = 43
}

struct LoadingView: View {
    let onFinish: () -> Void

    @State private var vm = LoadingViewModel()
    private let clock = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            // back to front: the pole goes behind the road, and the thief behind the title
            // so only his head pokes over the letters
            ZStack(alignment: .topLeading) {
                Color.white
                pole(space)
                road(space)
                thief(space)
                title(space)
                progressBar(space)
                busStop(space)
                angkot(space)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
        .onReceive(clock) { _ in vm.tick(1.0 / 60) }
        .onAppear { vm.onFinish = onFinish }
    }

    private func pole(_ space: DesignSpace) -> some View {
        place(Loading.pole, space) {
            RoundedRectangle(cornerRadius: space.px(4)).fill(Ink.black)
        }
    }

    private func road(_ space: DesignSpace) -> some View {
        place(Loading.road, space) {
            ZStack(alignment: .topLeading) {
                Color.clear
                Image("menu_road").resizable()
                    .rotationEffect(.degrees(180))
                    .frame(width: space.px(Loading.roadArt.width),
                           height: space.px(Loading.roadArt.height))
                    .offset(x: space.px(Loading.roadArt.minX - Loading.road.minX),
                            y: space.px(Loading.roadArt.minY - Loading.road.minY))
            }
            .frame(width: space.px(Loading.road.width),
                   height: space.px(Loading.road.height), alignment: .topLeading)
            .clipped()
        }
    }

    private func thief(_ space: DesignSpace) -> some View {
        place(Loading.thiefBox, space) {
            Image("loading_pencipet").resizable()
                .frame(width: space.px(Loading.thiefArt.width),
                       height: space.px(Loading.thiefArt.height))
                .rotationEffect(.degrees(Loading.thiefAngle))
        }
    }

    private func title(_ space: DesignSpace) -> some View {
        place(Loading.title.insetBy(dx: -Loading.titleSlack, dy: -Loading.titleSlack), space) {
            OutlinedText(string: "CIPET",
                         font: .skranji(space.px(Loading.titleSize)),
                         fill: Ink.yellow,
                         thickness: space.px(Loading.titleOutline),
                         twoRings: true)
        }
    }

    private func progressBar(_ space: DesignSpace) -> some View {
        Group {
            place(Loading.bar, space) {
                Capsule().fill(.white)
                    .overlay(Capsule().stroke(Ink.black, lineWidth: space.px(Loading.barStroke)))
            }
            place(CGRect(x: Loading.bar.minX, y: Loading.fillY,
                         width: vm.fillWidth, height: Loading.fillH), space) {
                Capsule().fill(Ink.yellow)
            }
        }
    }

    private func busStop(_ space: DesignSpace) -> some View {
        place(Loading.sign, space) {
            VStack(spacing: space.px(6)) {
                Image("loading_bus_icon").resizable()
                    .frame(width: space.px(Loading.busIcon.width),
                           height: space.px(Loading.busIcon.height))
                Text("STOP")
                    .font(.skranji(space.px(10)))
                    .tracking(space.px(4))
                    .foregroundStyle(Ink.black)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: space.px(7)))
            .overlay(RoundedRectangle(cornerRadius: space.px(7))
                .strokeBorder(Loading.signBlue, lineWidth: space.px(4.893)))
        }
    }

    private func angkot(_ space: DesignSpace) -> some View {
        let van = CGRect(x: vm.vanX, y: Loading.angkotY,
                         width: Loading.angkot.width, height: Loading.angkot.height)
        return place(van, space) { AngkotColored(group: van, space: space) }
    }
}

#Preview(traits: .landscapeLeft) { LoadingView {} }
