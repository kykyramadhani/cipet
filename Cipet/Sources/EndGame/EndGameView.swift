import SwiftUI

/// how the run finished: chose to stop, got spotted three times, or ran out of clock
enum Ending { case walkedAway, jailed, failed }

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

    // MARK: jailed: small card on the left, the cage over the thief, the sign top right
    static let jailThief   = CGRect(x: 543.02, y: 94, width: 198.8, height: 278.1)
    static let jailSign    = CGRect(x: 506, y: 33, width: 320, height: 100)
    static let jailCardArt = CGRect(x: 44.652, y: 71.612, width: 366.668, height: 260.379)
    static let jailTally   = CGPoint(x: 68, y: 101)
    static let jailWidth: CGFloat = 320
    static let jailButton    = CGRect(x: 68, y: 261, width: 320, height: 40)
    static let jailButtonArt = CGRect(x: 65.685, y: 258.696, width: 322.854, height: 45.3037)

    // MARK: failed: the big card shifted left, the thief peeking in with a sad bubble
    static let failCardArt = cardArt.offsetBy(dx: -107, dy: 0)
    static let failTitle   = CGRect(x: 130, y: 61, width: 400, height: 48)
    static let failTitleSize: CGFloat = 40
    static let failTally   = CGPoint(x: 130, y: 141)
    static let failWidth: CGFloat = 400
    static let failButton    = CGRect(x: 130, y: 310, width: 400, height: 40)
    static let failButtonArt = CGRect(x: 127.671, y: 307.696, width: 401.832, height: 45.3036)
    static let failThief   = CGRect(x: 609.96, y: 131, width: 227.24, height: 317.84)
    static let bubbleArt   = CGRect(x: 676.822, y: 79.775, width: 145.891, height: 107.506)
    static let bubbleText  = CGPoint(x: 750, y: 134)
    static let bubbleSize: CGFloat = 60

    // the tally on the red screens: three grey 20s 8 apart, then 20 down the black total
    static let greyRow:  CGFloat = 24
    static let greyGap:  CGFloat = 8
    static let totalGap: CGFloat = 20
    static let greySize: CGFloat = 20
}

// where a run finishes: the whole game's tally, not one round's. End Game on the succeed card
// comes here as Congrats?, the cage as JAILED, and the clock running out as Failed.
struct EndGameView: View {
    let session: GameSession
    var ending: Ending = .walkedAway
    let onHome: () -> Void

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)

            ZStack(alignment: .topLeading) {
                switch ending {
                case .walkedAway: congrats(space)
                case .jailed:     jailed(space)
                case .failed:     failed(space)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .fullBleed()
        .task { runEndChecks(); Audio.shared.play(.postGame) }
    }

    private var stats: [(String, String)] {
        [(t("Avg time"), session.avgTime), (t("Total Items"), "\(session.items)"),
         (t("Total Rounds"), "\(session.round)")]
    }
    private var total: String { "Rp \(session.takings)k" }

    @ViewBuilder private func congrats(_ space: DesignSpace) -> some View {
        Ink.yellow.ignoresSafeArea()
        Halftone(tint: Ink.glow, space: space)
        place(End.cardArt, space) { Image("eg_card").resizable() }
        place(End.title, space) {
            Text(t("Congrats?"))
                .font(.skranji(space.px(End.titleSize)))
                .foregroundStyle(Ink.black)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        ForEach(stats.indices, id: \.self) { i in
            statRow(stats[i].0, stats[i].1, End.labelSize, End.valueSize, Ink.grey,
                    CGRect(x: End.column.minX, y: End.firstY + CGFloat(i) * End.rowStep,
                           width: End.column.width, height: End.rowH), space)
        }
        statRow(t("Total Item value"), total, End.labelSize, End.valueSize, Ink.black,
                CGRect(x: End.column.minX, y: End.totalY, width: End.column.width, height: End.rowH),
                space)
        artButton(t("Back to Home"), "eg_button", End.button, End.buttonArt, space, onHome)
        place(End.thief, space) { Image("loading_pencipet").resizable() }
    }

    @ViewBuilder private func jailed(_ space: DesignSpace) -> some View {
        Ink.red.ignoresSafeArea()
        Halftone(tint: Ink.redGlow, space: space)
        place(End.jailThief, space) { Image("loading_pencipet").resizable() }
        Cage(space: space)
        JailSign(word: "JAILED", box: End.jailSign, space: space)
        place(End.jailCardArt, space) { Image("jail_card").resizable() }
        tally(End.jailTally, End.jailWidth, space)
        artButton(t("Back to Home"), "jail_button", End.jailButton, End.jailButtonArt, space, onHome)
    }

    @ViewBuilder private func failed(_ space: DesignSpace) -> some View {
        Ink.red.ignoresSafeArea()
        Halftone(tint: Ink.redGlow, space: space)
        place(End.failCardArt, space) { Image("eg_card").resizable() }
        place(End.failTitle, space) {
            Text(t("Try again next time"))
                .font(.skranji(space.px(End.failTitleSize)))
                .foregroundStyle(.black)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        tally(End.failTally, End.failWidth, space)
        artButton(t("Back to Home"), "fail_button", End.failButton, End.failButtonArt, space, onHome)
        place(End.failThief, space) { Image("loading_pencipet").resizable() }
        // the bubble's tail points down at him, so the art goes in upside down
        place(End.bubbleArt, space) { Image("fail_bubble").resizable().scaleEffect(y: -1) }
        Text(":(")
            .font(.skranji(space.px(End.bubbleSize), bold: false))
            .foregroundStyle(Ink.soft)
            .fixedSize()
            .position(x: space.x(End.bubbleText.x), y: space.y(End.bubbleText.y))
    }

    private func tally(_ at: CGPoint, _ width: CGFloat, _ space: DesignSpace) -> some View {
        Group {
            ForEach(stats.indices, id: \.self) { i in
                statRow(stats[i].0, stats[i].1, End.greySize, End.greySize, Ink.grey,
                        CGRect(x: at.x, y: at.y + CGFloat(i) * (End.greyRow + End.greyGap),
                               width: width, height: End.greyRow), space)
            }
            statRow(t("Total Item value"), total, End.labelSize, End.valueSize, .black,
                    CGRect(x: at.x, y: at.y + End.redTotalY, width: width, height: End.rowH), space)
        }
    }
}

extension End {
    /// where the black total starts under the three grey rows
    static var redTotalY: CGFloat { 3 * greyRow + 2 * greyGap + totalGap }
}

/// a label on the left and its value on the right, both centred on the row
func statRow(_ label: String, _ value: String, _ labelSize: CGFloat, _ valueSize: CGFloat,
             _ tint: Color, _ r: CGRect, _ space: DesignSpace) -> some View {
    place(r, space) {
        HStack(spacing: space.px(8)) {
            Text(label).font(.skranji(space.px(labelSize), bold: false))
            Spacer(minLength: 0)
            Text(value).font(.skranji(space.px(valueSize), bold: false))
        }
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(tint)
    }
}

/// one of the hand drawn buttons: the art bleeds past `box`, the word sits in the middle of it
func artButton(_ title: String, _ art: String, _ box: CGRect, _ artBox: CGRect,
               _ space: DesignSpace, _ action: @escaping () -> Void) -> some View {
    Button(action: action) {
        ZStack(alignment: .topLeading) {
            Image(art).resizable()
                .frame(width: space.px(artBox.width), height: space.px(artBox.height))
            Text(title)
                .font(.skranji(space.px(End.buttonSize), bold: false))
                .foregroundStyle(Ink.black)
                .fixedSize()
                .position(x: space.px(box.midX - artBox.minX), y: space.px(box.midY - artBox.minY))
        }
        .frame(width: space.px(artBox.width), height: space.px(artBox.height))
    }
    .buttonStyle(PressStyle())
    .position(x: space.x(artBox.midX), y: space.y(artBox.midY))
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

    // the red cards: the total clears the button, and the button sits on the card's bottom inset
    assert(End.jailTally.y + End.redTotalY + End.rowH < End.jailButton.minY)
    assert(End.failTally.y + End.redTotalY + End.rowH < End.failButton.minY)
    assert(End.jailButtonArt.contains(End.jailButton), "the art bleeds round the button")
    assert(End.failTitle.maxY + 32 == End.failTally.y, "32 under the title")
    assert(End.jailCardArt.contains(CGRect(origin: End.jailTally,
                                           size: CGSize(width: End.jailWidth, height: 200))))
    #endif
}

#Preview(traits: .landscapeLeft) { EndGameView(session: GameSession(), ending: .failed) {} }
