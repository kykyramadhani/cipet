import SwiftUI

// the onboarding, on the first Play only. every page is the real game scene — the same
// passengers, kid, driver and thief, drawn by the same code as a round — dimmed, with
// whatever the page is about lifted above the dim, and the design's card on top.
enum Tutorial {
    /// what a page lifts out of the dim
    enum Part { case angkot, pointer, pavement, target, thief, bars, suspicion, stealBar }

    struct Card {
        let text: String
        let box: CGRect
        enum Row { case none, next, play }
        let row: Row
        /// the room between the words and the row under them, which the design varies
        var gap: CGFloat = 14
        /// when the design lets the words run a touch wider than the card's padding
        var textWidth: CGFloat? = nil

    }

    /// how far a card that's come out taller than the design has to rise to stay this far
    /// off the bottom of the screen. a card that fits the design's box never moves.
    static let cardMargin: CGFloat = 6
    static func rise(_ box: CGRect, _ height: CGFloat) -> CGFloat {
        max(0, box.minY + height - (DesignSpace.screen.height - cardMargin))
    }

    struct Page {
        let cards: [Card]
        let lit: Set<Part>
        /// picking a target and a seat, rather than stealing
        var picking = false
        var kid = false
        var ghosts = false
        /// the yellow arrow's centre, pointing down at who or where to pick
        var pointer: CGPoint? = nil
        var suspicion = 0
        var grab: CGFloat = 0.08
        /// where the design nudges the round's pieces on this screen, against the round's own
        var angkotShift = CGSize.zero
        var barShift = CGSize.zero
        var suspicionShift = CGSize.zero
    }

    /// the tutorial's angkot, straight off the design: two on the far bench and the mark in
    /// the middle of the near one. real riders, all idle.
    static let target = Seating.Person.nearMid
    static let thiefSeat = Seating.thiefSpot(.nearLeft)
    static let cast = Arrangement(
        cast: [.farLeft: Rider(who: "Music"), .farRight: Rider(who: "Sleepy"), .nearMid: Rider(who: "BehindMusic")],
        start: [.farLeft: .alert, .farRight: .alert, .nearMid: .alert, .kid: .alert],
        kid: true)
    static let bars: [Seating.Person: CGFloat] = [.farLeft: 0.3, .farRight: 0.95]

    static let pages: [Page] = [
        Page(cards: [Card(text: "Choose your target", box: CGRect(x: 669, y: 199, width: 183, height: 122),
                          row: .next)],
             lit: [.angkot, .pointer, .pavement], picking: true, pointer: CGPoint(x: 351.9, y: 166.5)),
        Page(cards: [Card(text: "Pick the best seat to make your move",
                          box: CGRect(x: 669, y: 199, width: 183, height: 143), row: .next)],
             lit: [.angkot, .pointer], picking: true, kid: true, ghosts: true, pointer: CGPoint(x: 291.9, y: 166.5)),
        Page(cards: [Card(text: "Hold until the bar is full to steal the item.",
                          box: CGRect(x: 30, y: 94, width: 183, height: 112), row: .none),
                     Card(text: "Release to lower it.", box: CGRect(x: 656, y: 211, width: 198, height: 77),
                          row: .next, gap: 10, textWidth: 178)],
             lit: [.target, .thief, .stealBar], grab: 0.22,
             angkotShift: CGSize(width: 0, height: -2), barShift: CGSize(width: 4, height: -7),
             suspicionShift: CGSize(width: 5, height: -5)),
        Page(cards: [Card(text: "Beware of other passengers\u{2019} suspicion bar.",
                          box: CGRect(x: 461, y: 89, width: 183, height: 109), row: .none),
                     Card(text: "If a suspicion bar fills up, your suspicion level rises. Stop for 3 seconds to lower it.",
                          box: CGRect(x: 94, y: 211, width: 225, height: 170), row: .next)],
             lit: [.bars, .suspicion, .target, .thief], suspicion: 1),
        Page(cards: [Card(text: "If your suspicion level is full, you\u{2019}ll go to jail.",
                          box: CGRect(x: 121, y: 240, width: 183, height: 143), row: .next)],
             lit: [.bars, .suspicion, .target, .thief], suspicion: 3),
        Page(cards: [Card(text: "Fill the bar without raising too much suspicion, and you win!",
                          box: CGRect(x: 658, y: 178, width: 205, height: 168), row: .play)],
             lit: [.target, .thief, .stealBar], suspicion: 1, grab: 1),
    ]

    /// the dim over everything a page isnt pointing at
    static let dim = Color(red: 0.1317, green: 0.1276, blue: 0.1276).opacity(0.6)
    static let pointerArt = CGSize(width: 51.1577, height: 51.3432)
    static let textSize: CGFloat = 20
    static let linkSize: CGFloat = 18
}

struct TutorialView: View {
    let onFinish: () -> Void

    @State private var index = 0

    var body: some View {
        GeometryReader { geo in
            let space = DesignSpace(geo.size)
            let page = Tutorial.pages[index]

            ZStack(alignment: .topLeading) {
                Image("menu_road").resizable().scaledToFill()
                    .frame(width: space.px(DesignSpace.screen.width), height: space.px(DesignSpace.screen.height))
                    .position(x: space.x(DesignSpace.screen.width / 2), y: space.y(DesignSpace.screen.height / 2))
                if page.picking { picking(page, space) } else { stealing(page, space) }
                ForEach(page.cards.indices, id: \.self) { i in
                    TutorialCard(card: page.cards[i], space: space, onSkip: onFinish, onNext: next)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            // a fresh scene each page, so every animation starts from its first frame
            .id(index)
        }
        .fullBleed()
        .task { runTutorialChecks() }
    }

    /// the round's hud as it looks at the start, pause button and all (it's only a picture here)
    @ViewBuilder private func hud(_ space: DesignSpace) -> some View {
        TutorialHUD(show: [], clock: mmss(Steal.round), space: space)
        place(Steal.pauseArt, space) { Image("pv_pause").resizable() }
    }

    private func bar(_ shift: CGSize, _ space: DesignSpace) -> CGSize {
        CGSize(width: space.px(shift.width), height: space.px(shift.height))
    }

    private func next() {
        if index + 1 < Tutorial.pages.count { index += 1 } else { onFinish() }
    }

    // choosing a target and a seat: the hud dims, the whole angkot stays lit
    @ViewBuilder private func picking(_ page: Tutorial.Page, _ space: DesignSpace) -> some View {
        hud(space)
        RoundTag(round: 1, space: space)
        Tutorial.dim.ignoresSafeArea()
        let show: TutorialStep.Show = [page.kid ? .kid : [], page.ghosts ? .seatGhosts : []]
        TutorialAngkot(show: show, space: space,
                       ghostSeats: page.ghosts ? Tutorial.cast.seats(beside: Tutorial.target) : [],
                       hot: page.ghosts ? Tutorial.target : nil,
                       cast: Arrangement(cast: Tutorial.cast.cast, start: Tutorial.cast.start, kid: page.kid),
                       moods: Tutorial.cast.start, colored: true)
        if let p = page.pointer {
            place(CGRect(x: p.x - Tutorial.pointerArt.width / 2, y: p.y - Tutorial.pointerArt.height / 2,
                         width: Tutorial.pointerArt.width, height: Tutorial.pointerArt.height), space) {
                // the drawing points right; the design turns it to point down
                Image("tut_point").resizable().rotationEffect(.degrees(90))
            }
        }
        if page.lit.contains(.pavement) { TutorialPavement(space: space) }
    }

    // stealing: the whole round dims, and the page lifts out just what it's about. each
    // character is drawn once, either under the dim or over it, so nobody plays twice.
    @ViewBuilder private func stealing(_ page: Tutorial.Page, _ space: DesignSpace) -> some View {
        let lit = page.lit
        let drop = space.px(Steal.angkotDrop)
        let rest = Tutorial.cast.cast.filter { $0.key != Tutorial.target }
        let mark = Tutorial.cast.cast.filter { $0.key == Tutorial.target }

        TutorialAngkot(show: [], space: space, thiefAt: Tutorial.thiefSeat,
                       cast: Arrangement(cast: rest, kid: false),
                       aware: lit.contains(.bars) ? [:] : Tutorial.bars, moods: Tutorial.cast.start, colored: true)
            .offset(x: space.px(page.angkotShift.width), y: drop + space.px(page.angkotShift.height))
        hud(space)
        if !lit.contains(.stealBar) { StealBar(progress: page.grab, space: space).offset(bar(page.barShift, space)) }
        if !lit.contains(.suspicion) { SuspicionBar(lit: page.suspicion, space: space).offset(bar(page.suspicionShift, space)) }

        Tutorial.dim.ignoresSafeArea()

        TutorialAngkot(show: [], space: space, thiefAt: Tutorial.thiefSeat, hot: Tutorial.target,
                       cast: Arrangement(cast: mark, kid: false),
                       aware: lit.contains(.bars) ? Tutorial.bars : [:], moods: Tutorial.cast.start,
                       colored: true, thief: AnyView(ThiefActor(
                            beat: .stealing, seat: Tutorial.thiefSeat, reachingLeft: false,
                            behind: Seating.bench(of: Tutorial.thiefSeat) == 1, space: space, onFinish: { _ in })),
                       drawBody: false)
            .offset(x: space.px(page.angkotShift.width), y: drop + space.px(page.angkotShift.height))
        if lit.contains(.stealBar) { StealBar(progress: page.grab, space: space).offset(bar(page.barShift, space)) }
        if lit.contains(.suspicion) { SuspicionBar(lit: page.suspicion, space: space).offset(bar(page.suspicionShift, space)) }
    }
}

// one of the design's white cards: the words, then skip and an arrow, or Play now
struct TutorialCard: View {
    let card: Tutorial.Card
    let space: DesignSpace
    let onSkip: () -> Void
    let onNext: () -> Void

    /// how tall the card really came out, in design units
    @State private var height: CGFloat = 0

    var body: some View {
        place(card.box, space) {
            VStack(spacing: space.px(card.gap)) {
                Text(t(card.text))
                    .font(.skranji(space.px(Tutorial.textSize), bold: false))
                    .foregroundStyle(Ink.black)
                    .frame(width: space.px(card.textWidth ?? card.box.width - 28), alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    // a design-width line can hang past the padding, centred over it
                    .frame(width: space.px(card.box.width - 28))
                switch card.row {
                case .none: EmptyView()
                case .next:
                    HStack {
                        link("Skip", onSkip).accessibilityIdentifier("tutorial-skip")
                        Spacer(minLength: 0)
                        Button(action: onNext) {
                            Image("tut_arrow_next").resizable()
                                .frame(width: space.px(24), height: space.px(24))
                        }
                        .buttonStyle(PressStyle())
                        .contentShape(Rectangle().inset(by: -space.px(10)))
                        .accessibilityIdentifier("tutorial-next")
                    }
                case .play:
                    HStack {
                        Spacer(minLength: 0)
                        link("Play now", onNext).accessibilityIdentifier("tutorial-play")
                    }
                }
            }
            // the design's border is drawn over the edge and takes no room, so the words sit
            // 14 in from the box
            .padding(space.px(14))
            .frame(width: space.px(card.box.width))
            // never shorter than the design's card; a longer translation makes it taller
            // instead of clipping, at the same width and size of type
            .frame(minHeight: space.px(card.box.height))
            .fixedSize(horizontal: false, vertical: true)
            .background(Ink.paper, in: RoundedRectangle(cornerRadius: space.px(10)))
            .overlay(RoundedRectangle(cornerRadius: space.px(10)).strokeBorder(.black, lineWidth: space.px(6)))
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 / space.scale }
            // it grows downward from the design's top edge, and only rises by as much as it
            // takes to stay on screen
            .offset(y: -space.px(Tutorial.rise(card.box, height)))
            .frame(width: space.px(card.box.width), height: space.px(card.box.height), alignment: .top)
        }
    }

    private func link(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t(title)).underline()
                .font(.skranji(space.px(Tutorial.linkSize), bold: false))
                .foregroundStyle(Ink.black)
        }
        .buttonStyle(PressStyle())
        .contentShape(Rectangle().inset(by: -space.px(10)))
    }
}

private func runTutorialChecks() {
    #if DEBUG
    assert(Tutorial.pages.count == 6, "six screens, in the design's order")
    assert(Tutorial.pages.first!.lit.contains(.pavement), "it opens with the thief still on the kerb")
    if case .play = Tutorial.pages.last!.cards.last!.row {} else { assertionFailure("and ends on Play now") }
    let screen = CGRect(origin: .zero, size: DesignSpace.screen)
    for p in Tutorial.pages {
        for c in p.cards {
            assert(screen.contains(c.box), "\(c.text) runs off screen")
            // the design's own size stays put; anything taller rises just enough, never off the top
            assert(Tutorial.rise(c.box, c.box.height) == 0, "\(c.text) moved at its own size")
            let tall = c.box.height + 60
            assert(c.box.minY - Tutorial.rise(c.box, tall) + tall <= screen.height - Tutorial.cardMargin + 0.001)
        }
    }
    // the tutorial's people are real riders, and the thief sits beside the mark
    for r in Tutorial.cast.cast.values { assert(Rider.all.contains(r), "\(r.who) isnt a gameplay rider") }
    assert(Tutorial.cast.seats(beside: Tutorial.target).contains(Tutorial.thiefSeat))
    #endif
}

#Preview(traits: .landscapeLeft) { TutorialView {} }
