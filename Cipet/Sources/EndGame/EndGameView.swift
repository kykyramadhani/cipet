import SwiftUI

enum End {
    // same halftone as the countdown card and the jail screen, just tinted for a yellow bg
    static let dots = CGRect(x: -100.003, y: -257.998, width: 1074.986, height: 918.275)

    static let card    = CGRect(x: 187,    y: 31,    width: 500,     height: 340)
    static let cardArt = CGRect(x: 183.65, y: 28.79, width: 506.668, height: 346.217)
    static let thief   = CGRect(x: 136,    y: 61,    width: 227.24,  height: 317.84)

    /// the whole right hand column of the card: heading, the tally, and the button
    static let column = CGRect(x: 363, y: 61, width: 300, height: 289)
    static let title  = CGRect(x: 363, y: 61, width: 300, height: 72)
    static let titleSize: CGFloat = 60
    static let labelSize: CGFloat = 22
    static let valueSize: CGFloat = 24

    // the rows are laid out by hand rather than stacked, because skranji's line boxes are
    // taller than the design's and the last one ended up under the button
    static let rowH:    CGFloat = 26.4
    static let rowStep: CGFloat = 34.4   // row plus the 8 between them
    static let firstY:  CGFloat = 149
    static let totalY:  CGFloat = 264.2  // the black one, after the bigger gap

    static let button     = CGRect(x: 363,    y: 310,     width: 300,     height: 40)
    static let buttonArt  = CGRect(x: 360.68, y: 307.696, width: 303.054, height: 45.3038)
    static let buttonSize: CGFloat = 20
}

// where a run finishes: the whole game's tally, not one round's. reached from End Game on
// the succeed card and from the jail screen.
struct EndGameView: View {
    let session: GameSession
    let onHome: () -> Void

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                Ink.yellow.ignoresSafeArea()
                halftone(space)
                place(End.cardArt, space) { Image("eg_card").resizable() }
                tally(space)
                homeButton(space)
                place(End.thief, space) { Image("loading_pencipet").resizable() }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
        .task { runEndChecks(); Audio.shared.play(.postGame) }
    }

    private func halftone(_ space: DesignSpace) -> some View {
        Image("round_dots").renderingMode(.template).resizable()
            .foregroundStyle(Ink.glow)
            .frame(width: space.px(End.dots.width), height: space.px(End.dots.height))
            .position(x: space.x(End.dots.midX), y: space.y(End.dots.midY))
    }

    private func tally(_ space: DesignSpace) -> some View {
        let stats = [("Avg time", session.avgTime),
                     ("Total Items", "\(session.items)"),
                     ("Total Rounds", "\(session.round)")]
        return Group {
            place(End.title, space) {
                Text("Congrats?")
                    .font(.skranji(space.px(End.titleSize)))
                    .foregroundStyle(Ink.black)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(stats.indices, id: \.self) { i in
                row(stats[i].0, stats[i].1, Ink.grey,
                    End.firstY + CGFloat(i) * End.rowStep, space)
            }
            row("Total Item value", "Rp \(session.takings)k", Ink.black, End.totalY, space)
        }
    }

    private func row(_ label: String, _ value: String, _ tint: Color,
                     _ y: CGFloat, _ space: DesignSpace) -> some View {
        place(CGRect(x: End.column.minX, y: y, width: End.column.width, height: End.rowH),
              space) {
            HStack(spacing: space.px(8)) {
                Text(label).font(.skranji(space.px(End.labelSize), bold: false))
                Spacer(minLength: 0)
                Text(value).font(.skranji(space.px(End.valueSize), bold: false))
            }
            .lineLimit(1)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(tint)
        }
    }

    private func homeButton(_ space: DesignSpace) -> some View {
        place(End.buttonArt, space) {
            Button(action: onHome) {
                ZStack {
                    Image("eg_button").resizable()
                    Text("Back to Home")
                        .font(.skranji(space.px(End.buttonSize), bold: false))
                        .foregroundStyle(Ink.black)
                }
            }
            .buttonStyle(PressStyle())
        }
    }
}

func runEndChecks() {
    #if DEBUG
    // the card is centred and the artwork bleeds evenly round it
    assert(abs(End.card.midX - DesignSpace.screen.width / 2) < 0.5)
    assert(abs(End.card.midY - DesignSpace.screen.height / 2) < 0.5)
    assert(End.cardArt.contains(End.card), "the drawn border hangs outside the box")

    // everything the player reads sits inside the card
    assert(End.card.contains(End.column))
    // the tally has to finish before the button starts, which is what it didnt do at first
    assert(End.title.maxY < End.firstY)
    assert(End.firstY + 2 * End.rowStep + End.rowH < End.totalY, "the greys clear the black one")
    assert(End.totalY + End.rowH < End.button.minY, "and the total clears the button")
    assert(End.column.contains(End.button))
    assert(End.buttonArt.contains(End.button))
    assert(End.button.maxY == End.column.maxY, "the button is pinned to the bottom of the column")

    // the thief is to the left of the text, not over it
    assert(End.thief.maxX <= End.column.minX + 1)
    assert(End.dots.width > DesignSpace.screen.width, "the halftone covers the whole screen")
    #endif
}

#Preview(traits: .landscapeLeft) { EndGameView(session: GameSession()) {} }
