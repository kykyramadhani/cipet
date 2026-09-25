import SwiftUI

enum Rec {
    // the card is the settings card's twin — same artwork, same size, sat a little lower
    static let dim   = Color(red: 34 / 255, green: 33 / 255, blue: 33 / 255)
    static let card  = CGRect(x: 216.659, y: 57.68, width: 440.666, height: 289.331)
    static let close = CGRect(x: 628.62,  y: 45.62, width: 38.76,   height: 38.76)

    static let titleAt = CGPoint(x: 437, y: 123)
    static var title: CGRect { CardTitle.box(titleAt) }

    // two tiles side by side, measured from the card's own top-left at 220, 60
    static let tiles    = CGRect(x: 274, y: 166, width: 325.5, height: 114)
    static let tile     = CGSize(width: 156.75, height: 114)
    static let tileGap:   CGFloat = 12
    static let tileRadius: CGFloat = 6
    static let tileBorder: CGFloat = 3

    /// inside a tile: the number, a gap, then what it's the number of
    static let columnGap: CGFloat = 9
    static let valueBox   = CGSize(width: 100, height: 34)
    static let valueSize:   CGFloat = 24
    static let labelSize:   CGFloat = 16

    /// skranji's own line at the label's size — its "normal" is 54.336 at 40
    static let labelLine: CGFloat = 54.336 * labelSize / 40

    // the design's column is 103 x 59, which is shorter and narrower than these two lines
    // actually need: the pair wanted 65 and got 59, so swiftui shrank both to fit and the
    // number came out at 21 point against the 24 it is set in. the column is measured from
    // the type now, and takes the width of its tile so a longer label in another language
    // has somewhere to go. both are centred in the tile either way, so nothing moves.
    static let column = CGSize(width: tile.width - 16,
                               height: valueBox.height + columnGap + labelLine)

    static func tileX(_ i: Int) -> CGFloat { tiles.minX + CGFloat(i) * (tile.width + tileGap) }
}

// what the menu's Record button opens: the two numbers worth keeping. it reads straight
// off the store rather than taking them as arguments, because there is only ever one
// record and it is the same one the button's own presence is decided by.
struct RecordPanel: View {
    @Binding var shown: Bool
    let space: DesignSpace

    private var record: Record { Record.shared }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rec.dim.opacity(0.6).ignoresSafeArea().onTapGesture { close() }

            place(Rec.card, space) { Image("settings_card").resizable() }
            title
            tile(0, fill: Ink.yellow, border: Ink.soft,
                 value: record.roundText, label: t("Highest Round"))
            tile(1, fill: .white, border: Ink.black,
                 value: record.valueText, label: t("Top Value"))
            closeButton
        }
        .task { runRecordChecks(); runRecordPanelChecks() }
    }

    private func close() { withAnimation(.easeInOut(duration: 0.2)) { shown = false } }

    private var title: some View {
        CardTitle(text: t("Record"), centre: Rec.titleAt, space: space)
    }

    private func tile(_ i: Int, fill: Color, border: Color,
                      value: String, label: String) -> some View {
        let box = CGRect(x: Rec.tileX(i), y: Rec.tiles.minY,
                         width: Rec.tile.width, height: Rec.tile.height)
        return Group {
            place(box, space) {
                RoundedRectangle(cornerRadius: space.px(Rec.tileRadius)).fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: space.px(Rec.tileRadius))
                        .strokeBorder(border, lineWidth: space.px(Rec.tileBorder)))
            }
            place(CGRect(x: box.midX - Rec.column.width / 2,
                         y: box.midY - Rec.column.height / 2,
                         width: Rec.column.width, height: Rec.column.height), space) {
                VStack(spacing: space.px(Rec.columnGap)) {
                    Text(value)
                        .font(.skranji(space.px(Rec.valueSize)))
                        .foregroundStyle(Ink.black)
                        .lineLimit(1).minimumScaleFactor(0.55)
                        .frame(width: space.px(Rec.valueBox.width),
                               height: space.px(Rec.valueBox.height))
                    Text(label)
                        .font(.skranji(space.px(Rec.labelSize), bold: false))
                        .foregroundStyle(Ink.soft)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
            }
        }
    }

    private var closeButton: some View {
        place(Rec.close, space) {
            Button(action: close) { Image("settings_close").resizable() }
                .buttonStyle(PressStyle())
        }
    }
}

func runRecordPanelChecks() {
    #if DEBUG
    // the card is the settings card in the same frame, just sat a touch lower
    assert(Rec.card.size == Cog.card.size, "both panels are the one piece of artwork")
    assert(abs(Rec.card.midX - DesignSpace.screen.width / 2) < 0.5, "and it's centred")

    // everything the player reads is inside the card
    let inside = Rec.card.insetBy(dx: 6, dy: 6)
    assert(inside.contains(Rec.title))
    assert(inside.contains(CGRect(x: Rec.tileX(0), y: Rec.tiles.minY,
                                  width: Rec.tiles.width, height: Rec.tiles.height)))

    // the column fits its tile, and the type fits the column — no line is being squeezed
    // down by minimumScaleFactor to make it fit
    assert(Rec.column.width <= Rec.tile.width && Rec.column.height <= Rec.tile.height)
    assert(Rec.column.height >= Rec.valueBox.height + Rec.columnGap + Rec.labelLine - 0.01)
    assert(abs(GlyphLine("Highest Round", size: Rec.labelSize).box.height - Rec.labelLine) < 0.01,
           "the label row is the font's own line")
    for label in ["Highest Round", "Top Value"] {
        for copy in [label, Indonesian.table[label] ?? label] {
            let w = GlyphLine(copy, size: Rec.labelSize).box.width
            assert(w <= Rec.column.width, "\(copy) is \(Int(w)) wide against \(Int(Rec.column.width))")
        }
    }
    // the numbers the panel realistically shows fit the design's box at the size they are
    // set in. the box holds up to Rp999k; a bigger haul than that would be scaled down by
    // the text itself, which is what minimumScaleFactor is there for.
    for value in ["0", "99", "9999", "Rp0k", "Rp120k", "Rp999k"] {
        let w = GlyphLine(value, size: Rec.valueSize, bold: true).box.width
        assert(w <= Rec.valueBox.width,
               "\(value) is \(Int(w)) wide against \(Int(Rec.valueBox.width)) of box")
    }

    // two tiles with a gap between them, filling the row exactly
    assert(abs(2 * Rec.tile.width + Rec.tileGap - Rec.tiles.width) < 0.01)
    assert(Rec.tileX(1) > Rec.tileX(0) + Rec.tile.width, "they dont overlap")
    // the cross straddles the card's top right corner rather than sitting inside it,
    // the same way the settings one does
    let corner = CGRect(x: 220, y: 60, width: 434, height: 283)   // the card without its bleed
    assert(Rec.close.minY < corner.minY && Rec.close.maxY > corner.minY, "it crosses the top edge")
    assert(Rec.close.minX < corner.maxX && Rec.close.maxX > corner.maxX, "and the right one")
    assert(Rec.card.contains(corner), "the drawn border hangs outside the card's box")
    #endif
}

#Preview(traits: .landscapeLeft) {
    GeometryReader { geo in
        RecordPanel(shown: .constant(true), space: DesignSpace(geo.size))
    }
}
