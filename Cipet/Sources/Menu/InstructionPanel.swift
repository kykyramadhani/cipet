import SwiftUI

enum Instr {
    // 333:1275. the card is a plain rounded rectangle rather than a piece of artwork, so
    // unlike the settings and record panels there is nothing to place around it.
    static let card   = CGRect(x: 209, y: 47, width: 440, height: 313)
    static let radius: CGFloat = 9.323
    /// the design file says 8, but it renders at six, centred on the edge — which is also
    /// what every other card in the game does
    static let border: CGFloat = 6

    /// the same cross the settings panel uses, straddling the top right corner
    static let close = CGRect(x: 621.62, y: 24.62, width: 38.76, height: 38.76)

    static let titleAt = CGPoint(x: 429, y: 88.838)
    static var title: CGRect { CardTitle.box(titleAt) }

    /// the picture has its own origin, so every number below is a small one measured off the
    /// design rather than a screen coordinate with 237 added to it.
    //
    // the card stacks heading, gap, picture and centres the lot, so giving the heading the
    // same fifty point line as every other card pushes this down by half the growth. the
    // heading's own centre does not move, because the column is centred either way.
    static let titleGap: CGFloat = 9.323
    static let diagram = CGRect(x: 237, y: 88.838 + CardTitle.lineBox / 2 + titleGap,
                                width: 384, height: 220)

    static func dia(_ r: CGRect) -> CGRect {
        r.offsetBy(dx: diagram.minX, dy: diagram.minY)
    }

    // MARK: the callouts
    static let noteWidth:  CGFloat = 107
    static let notePad:    CGFloat = 8.186
    static let noteBorder: CGFloat = 3.508
    static let noteRadius: CGFloat = 5.847
    static let noteSize:   CGFloat = 12

    static let notes: [CGPoint] = [CGPoint(x: 0,   y: 11),     // beware of the suspicion bar
                                   CGPoint(x: 33,  y: 130),    // a full bar raises the level
                                   CGPoint(x: 147, y: 142),    // a full level is jail
                                   CGPoint(x: 277, y: 74)]     // and how you win

    /// the numbered discs. they do not run in reading order down the page, so the number is
    /// the index and the place is looked up rather than worked out.
    static let badge: CGFloat = 26
    static let badgeArt = CGSize(width: 26.52, height: 26.52)
    static let badgeNumber = CGPoint(x: 9, y: 5)
    static let badgeSize: CGFloat = 12
    static let badges: [CGPoint] = [CGPoint(x: 101.5, y:  82.34),   // 1 hold anywhere
                                    CGPoint(x: -16,   y:  -6.462),  // 2 their suspicion bar
                                    CGPoint(x:  20.5, y: 116.84),   // 3 the level
                                    CGPoint(x: 127.5, y: 132.84),   // 4 jail
                                    CGPoint(x: 264.5, y:  58.84)]   // 5 succeeding

    // MARK: the angkot, drawn small
    /// the van sits here in the picture, at this fraction of its real size. inside it
    /// everything is stated in the angkot's own coordinates — the same ones the round uses,
    /// so the drawing and the game can never quietly drift apart.
    static let vanAt = CGPoint(x: 97, y: -29)
    static let vanScale: CGFloat = 0.45484

    static func van(_ r: CGRect) -> CGRect {
        dia(CGRect(x: vanAt.x + r.minX * vanScale, y: vanAt.y + r.minY * vanScale,
                   width: r.width * vanScale, height: r.height * vanScale))
    }

    /// the driver sits back with the passengers here rather than up in his cab, and the
    /// thief is over at the door, so these two do not come from the round's own layout
    static let sopir = CGRect(x: 289.14, y: 197.43, width: 62.222, height: 84)
    static let thief = CGRect(x: 167.2,  y: 196.3,  width: 57.4,   height: 80.3)

    /// two of them have a bar over their head, each part full
    static let awareBars: [(box: CGRect, level: CGFloat)] = [
        (CGRect(x: 41,  y: 101, width: 68, height: 20), 0.32),
        (CGRect(x: 161, y: 101, width: 68, height: 20), 0.78)]

    // the three slot meter, in the angkot's coordinates. the widget is 160 x 40 with its
    // badge hung off the left, laid out exactly as the round lays it out.
    static let levelNode = CGRect(x: 145, y: 344, width: 160, height: 40)
    static let levelOutlineNudge = CGSize(width: -2.854, height: -1.731)
    static let levelBadgeAt: CGFloat = -26
    static let levelBadgeBox: CGFloat = 44
    static let levelSlotsAt = CGPoint(x: 21.6, y: 8.4)
    static let levelLit = 1

    // MARK: the steal bar, which is drawn at the picture's scale and not the van's
    static let holdLabel = CGRect(x: 118.94, y: 93.106, width: 126.305, height: 18.961)
    static let holdText  = CGRect(x: 128.41, y: 95.58, width: 110, height: 14)
    static let holdSize:  CGFloat = 8.231
    static let track     = CGRect(x: 105.501, y: 106.803, width: 172.88, height: 21.093)
    static let trackFill = CGRect(x: 109.08, y: 110.88, width: 13.673, height: 12.616)
    static let coin      = CGRect(x: 247.38, y: 95.1, width: 31.552, height: 32.214)
    static let hand      = CGRect(x: 112.76, y: 102.99, width: 29.631, height: 29.631)
}

// what the info button opens, from the menu and from the pause card: one picture of a round
// with everything on it named. it is a still, not a replay — the same artwork the round is
// built from, arranged to be read rather than played.
struct InstructionPanel: View {
    @Binding var shown: Bool
    let space: DesignSpace

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rec.dim.opacity(0.6).ignoresSafeArea().onTapGesture { close() }

            place(Instr.card, space) {
                RoundedRectangle(cornerRadius: space.px(Instr.radius)).fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: space.px(Instr.radius))
                        .stroke(Ink.black, lineWidth: space.px(Instr.border)))
            }
            title
            behindTheVan
            angkot
            overTheVan
            inFront
            closeButton
        }
        .task { runInstructionChecks(); runCardTitleChecks() }
    }

    private func close() { withAnimation(.easeInOut(duration: 0.2)) { shown = false } }

    private var title: some View {
        CardTitle(text: t("Instruction"), centre: Instr.titleAt, space: space)
    }

    private var closeButton: some View {
        place(Instr.close, space) {
            Button(action: close) { Image("settings_close").resizable() }
                .buttonStyle(PressStyle())
        }
    }

    // MARK: the picture, in the order the design stacks it

    /// the two notes on the left are tucked under the van, so its nose overlaps them
    private var behindTheVan: some View {
        Group {
            note(0, t("Beware of other passengers suspicion bar."))
            note(1, t("If the suspicion bar is full, your suspicion level will increase"))
            badge(1)
            badge(2)
        }
    }

    private var angkot: some View {
        Group {
            art("loading_angkot_wheel", Instr.van(Tut.wheel))
            art("tut_angkot_interior",  Instr.van(Tut.interior))
            art("tut_kiri_a", Instr.van(Tut.kiriA))
            art("tut_kiri_b", Instr.van(Tut.kiriB))
            art("tut_sopir",  Instr.van(Instr.sopir))
            art("tut_kanan",  Instr.van(Tut.kanan))
            art("loading_pencipet", Instr.van(Instr.thief))
            art("angkot_exterior_colored", Instr.van(Tut.exterior))
        }
    }

    /// the marked passenger and the bars go on again over the van's panels, so they read
    /// through the window rather than from behind it
    private var overTheVan: some View {
        Group {
            note(2, t("If the level full you'll get into jail"))
            level
            art("tut_kiri_a", Instr.van(Tut.kiriA))
            ForEach(Instr.awareBars.indices, id: \.self) { i in
                awareBar(Instr.awareBars[i].box, Instr.awareBars[i].level)
            }
        }
    }

    private var inFront: some View {
        Group {
            note(3, t("You'll succeed if the bar is full by keeping passenger awareness safe"))
            stealBar
            badge(0)
            badge(3)
            badge(4)
        }
    }

    /// one passenger's bar: the same three pieces the round draws, shrunk
    private func awareBar(_ box: CGRect, _ level: CGFloat) -> some View {
        let fill = Tut.awareFill
        let k = Instr.vanScale
        return Group {
            art("tut_aware_track",
                Instr.van(Tut.centred(Tut.awareTrack.offsetBy(dx: box.minX, dy: box.minY),
                                      on: Tut.awareArt)))
            place(Instr.van(CGRect(x: box.minX + fill.minX, y: box.minY + fill.minY,
                                   width: fill.width * level, height: fill.height)), space) {
                TwoToneBar(core: Ink.red, rim: Ink.redGlow,
                           radius: space.px(k * fill.height / 2), edge: space.px(k * 1.4))
            }
            place(Instr.van(Tut.eye.offsetBy(dx: box.minX, dy: box.minY)), space) {
                Circle().fill(Ink.snow)
                    .overlay(Circle().strokeBorder(Ink.black, lineWidth: space.px(k * 1.429)))
                    .overlay {
                        Image("tut_eye").resizable()
                            .frame(width: space.px(k * Tut.eyeArt.width),
                                   height: space.px(k * Tut.eyeArt.height))
                    }
            }
        }
    }

    /// the three slot meter with one strike already against you, so the note beside it has
    /// something to point at
    private var level: some View {
        let n = Instr.levelNode
        let k = Instr.vanScale
        let outline = CGRect(x: n.minX + Instr.levelOutlineNudge.width,
                             y: n.minY + Instr.levelOutlineNudge.height,
                             width: Tut.suspOutline.width, height: Tut.suspOutline.height)
        let badgeBox = CGRect(x: n.minX + Instr.levelBadgeAt - 0.431,
                              y: n.midY - Instr.levelBadgeBox / 2 - 0.431,
                              width: Tut.suspBadge.width, height: Tut.suspBadge.height)
        return Group {
            art("tut_susp_outline", Instr.van(outline))
            art("tut_susp_badge",   Instr.van(badgeBox))
            ForEach(0..<Tut.slots, id: \.self) { i in
                let x = n.minX + Instr.levelSlotsAt.x
                        + CGFloat(i) * (Tut.slot.width + Tut.slotGap)
                let on = i < Instr.levelLit
                let r = space.px(k * Tut.slotRadius)
                place(Instr.van(CGRect(origin: CGPoint(x: x, y: n.minY + Instr.levelSlotsAt.y),
                                       size: Tut.slot)), space) {
                    RoundedRectangle(cornerRadius: r).fill(on ? Ink.redGlow : Ink.paper)
                        .overlay(RoundedRectangle(cornerRadius: r)
                            .strokeBorder(on ? Ink.red : Ink.pale,
                                          lineWidth: space.px(k * Tut.slotBorder)))
                }
            }
        }
    }

    /// the bar you actually hold, part filled, with the hand still on it
    private var stealBar: some View {
        Group {
            art("tut_hold_label", Instr.dia(Instr.holdLabel))
            place(Instr.dia(Instr.holdText), space) {
                Text(t("Hold anywhere to fill the bar"))
                    .font(.skranji(space.px(Instr.holdSize), bold: false))
                    .foregroundStyle(.black)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            art("tut_steal_track", Instr.dia(Instr.track))
            place(Instr.dia(Instr.trackFill), space) {
                TwoToneBar(core: Ink.yellow, rim: Ink.glow,
                           radius: space.px(Instr.trackFill.height / 2), edge: space.px(1.2))
            }
            art("tut_steal_wallet", Instr.dia(Instr.coin))
            art("tut_hand", Instr.dia(Instr.hand))
        }
    }

    // MARK: the labels

    /// a note is as tall as its sentence, so unlike everything else here it cannot be placed
    /// in a box — it hangs from its top left corner and grows down
    private func note(_ i: Int, _ text: String) -> some View {
        let at = Instr.notes[i]
        // the padding is measured from the note's own edge and the border straddles that
        // edge rather than eating into it, so the sentence gets the full width less padding.
        // taking the border off as well is what made every note wrap a word early.
        let inner = space.px(Instr.noteWidth - 2 * Instr.notePad)
        return Text(text)
            .font(.skranji(space.px(Instr.noteSize), bold: false))
            .foregroundStyle(Ink.black)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: inner, alignment: .leading)
            .padding(space.px(Instr.notePad))
            .background(Ink.paper, in: RoundedRectangle(cornerRadius: space.px(Instr.noteRadius)))
            .overlay(RoundedRectangle(cornerRadius: space.px(Instr.noteRadius))
                .stroke(.black, lineWidth: space.px(Instr.noteBorder)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .offset(x: space.x(Instr.diagram.minX + at.x),
                    y: space.y(Instr.diagram.minY + at.y))
    }

    private func badge(_ i: Int) -> some View {
        let at = Instr.badges[i]
        let box = CGRect(x: at.x, y: at.y, width: Instr.badge, height: Instr.badge)
        return Group {
            art("tut_step_badge", Instr.dia(Tut.centred(box, on: Instr.badgeArt)))
            place(Instr.dia(CGRect(x: at.x + Instr.badgeNumber.x, y: at.y + Instr.badgeNumber.y,
                                   width: 14, height: 16)), space) {
                Text("\(i + 1)")
                    .font(.skranji(space.px(Instr.badgeSize), bold: false))
                    .foregroundStyle(.black)
                    .fixedSize()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func art(_ name: String, _ r: CGRect) -> some View {
        place(r, space) { Image(name).resizable() }
    }
}

func runInstructionChecks() {
    #if DEBUG
    // the card is on the screen with room round it, and the cross straddles its top right
    // corner the way the settings one does
    let screen = CGRect(origin: .zero, size: DesignSpace.screen)
    assert(screen.insetBy(dx: 8, dy: 8).contains(Instr.card))
    assert(Instr.close.minY < Instr.card.minY && Instr.close.maxY > Instr.card.minY)
    assert(Instr.close.minX < Instr.card.maxX && Instr.close.maxX > Instr.card.maxX)

    // the heading and the picture are both on the card, in that order, both centred on it
    assert(Instr.card.contains(Instr.title) && Instr.card.contains(Instr.diagram))
    assert(Instr.title.maxY <= Instr.diagram.minY, "the heading clears the picture")
    // the fifty point heading is drawn taller than the card reserves for it, so the gap
    // below is what stops it landing on the van
    assert(Instr.title.height > CardTitle.lineBox)
    assert(Instr.diagram.maxY < Instr.card.maxY, "and the picture still fits under it")
    assert(abs(Instr.diagram.midX - Instr.card.midX) < 0.01)
    assert(abs(Instr.title.midX - Instr.card.midX) < 0.01)

    // five numbered discs: one per note, plus the one labelling the bar itself
    assert(Instr.badges.count == 5 && Instr.notes.count == 4)
    var seen: Set<String> = []
    for p in Instr.badges { seen.insert("\(Int(p.x)),\(Int(p.y))") }
    assert(seen.count == Instr.badges.count, "every disc has its own place")
    // each note is numbered by the disc sat on its top left corner, so every note has to
    // have one within reach of that corner — a disc that drifts off, or a note that never
    // got one, is the kind of thing only a screenshot would otherwise catch
    for at in Instr.notes {
        let near = Instr.badges.contains { abs($0.x - at.x) < 24 && abs($0.y - at.y) < 24 }
        assert(near, "the note at \(at) has no number on it")
    }

    // the van is drawn at a fraction of itself, and at the fraction the design used
    assert(abs(Instr.van(Tut.wheel).width - 199.818) < 0.1, "the van is 199.8 across")
    assert(abs(Instr.van(Tut.exterior).width / Tut.exterior.width - Instr.vanScale) < 0.0001)
    let kiri = Instr.van(Tut.kiriA)
    assert(abs(kiri.minX - Instr.dia(.zero).minX - 172.73) < 0.2, "and its people with it")
    assert(abs(kiri.minY - Instr.dia(.zero).minY - 21.46) < 0.2)

    // each bar sits over somebody — a bar with nobody under it means nothing
    for bar in Instr.awareBars {
        assert(bar.level > 0 && bar.level < 1, "part full, so it reads as a bar")
        assert([Tut.kiriA, Tut.kiriB].contains { abs($0.midX - bar.box.midX) < 4 })
    }

    // the meter reads one strike of three: part way, not empty and not jail
    assert(Instr.levelLit > 0 && Instr.levelLit < Tut.slots)
    let slotsEnd = Instr.levelSlotsAt.x + CGFloat(Tut.slots) * Tut.slot.width
                   + CGFloat(Tut.slots - 1) * Tut.slotGap
    assert(slotsEnd < Instr.levelNode.width, "three slots fit inside the meter")

    // the hand is on the bar it is holding, the wallet is at the end he has not reached
    assert(Instr.track.insetBy(dx: -6, dy: -12).contains(Instr.hand.insetBy(dx: 4, dy: 4)))
    assert(Instr.coin.midX > Instr.hand.midX, "the wallet is what he is reaching for")
    assert(Instr.trackFill.maxX < Instr.coin.minX, "and the bar has not got there yet")
    // the label rides the top edge of the bar rather than clearing it, which is the
    // arrangement it is copying from the round
    assert(Instr.holdLabel.midY < Instr.track.midY, "the label is the top half of the widget")
    assert(Instr.holdLabel.maxY > Instr.track.minY, "and it sits on the bar, not above it")
    assert(Tut.holdLabel.maxY > Tut.track.minY, "the way the round has it")
    #endif
}

#Preview(traits: .landscapeLeft) {
    GeometryReader { geo in
        InstructionPanel(shown: .constant(true), space: DesignSpace(geo.size))
    }
}
