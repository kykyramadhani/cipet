import SwiftUI

// one passenger's suspicion, sat over their head. it's drawn at the design's 68x20 and then
// scaled to fit `box`, so a bench of neighbours can each have one without them touching.
struct AwarenessBar: View {
    let box: CGRect        // where the bar goes, in the angkot's coordinates
    let level: CGFloat     // 0...1
    let space: DesignSpace

    var body: some View {
        let fill = Tut.awareFill, track = Tut.centred(Tut.awareTrack, on: Tut.awareArt)
        place(Tut.inAngkot(box), space) {
            ZStack(alignment: .topLeading) {
                Image("tut_aware_track").resizable()
                    .frame(width: space.px(track.width), height: space.px(track.height))
                    .offset(x: space.px(track.minX), y: space.px(track.minY))
                TwoToneBar(core: Ink.red, rim: Ink.redGlow,
                           radius: space.px(fill.height / 2), edge: space.px(1.4))
                    .frame(width: space.px(fill.width * min(1, max(0, level))), height: space.px(fill.height))
                    .offset(x: space.px(fill.minX), y: space.px(fill.minY))
                Circle().fill(Color(white: 250 / 255))
                    .overlay(Circle().strokeBorder(Ink.black, lineWidth: space.px(1.429)))
                    .overlay {
                        Image("tut_eye").resizable()
                            .frame(width: space.px(Tut.eyeArt.width), height: space.px(Tut.eyeArt.height))
                    }
                    .frame(width: space.px(Tut.eye.width), height: space.px(Tut.eye.height))
            }
            .frame(width: space.px(Tut.awareBox.width), height: space.px(Tut.awareBox.height),
                   alignment: .topLeading)
            .scaleEffect(box.width / Tut.awareBox.width)
        }
    }
}

// the one thats actually moving: fills up, loops, and the hand rides the head of it
struct StealBar: View {
    let progress: CGFloat
    let space: DesignSpace

    var body: some View {
        let width = Tut.fill.width * progress

        Group {
            place(Tut.inBar(Tut.holdLabel), space) { Image("tut_hold_label").resizable() }
            place(Tut.inBar(Tut.holdText), space) {
                Text(t("Hold anywhere to fill the bar"))
                    .font(.skranji(space.px(Tut.holdSize), bold: false))
                    .foregroundStyle(.black)
                    .fixedSize()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            place(Tut.inBar(Tut.track), space) { Image("tut_steal_track").resizable() }
            place(Tut.inBar(CGRect(x: Tut.fill.minX, y: Tut.fill.minY,
                                   width: width, height: Tut.fill.height)), space) {
                TwoToneBar(core: Ink.yellow, rim: Ink.glow,
                           radius: space.px(9), edge: space.px(2.2))
            }
            place(Tut.inBar(Tut.coin), space) { Image("tut_steal_wallet").resizable() }
            place(Tut.inBar(CGRect(x: Tut.handX(progress) - Tut.hand.width / 2, y: Tut.handY,
                                   width: Tut.hand.width, height: Tut.hand.height)), space) {
                Image("tut_hand").resizable()
            }
        }
    }
}

func runBarChecks() {
    #if DEBUG
    // the slots are the design's own: 40 x 23.2 with a 3.2 gap, 3.2 border, 8 radius.
    // the colours are Red/50 on Red/100 lit, Neutral/200 on Neutral/300 not.
    assert(Tut.slot == CGSize(width: 40, height: 23.2) && Tut.slotGap == 3.2)
    assert(Tut.slotRadius == 8 && Tut.slotBorder == 3.2)

    assert(Tut.handX(0) == Tut.fill.minX, "empty, the hand is at the start of the bar")
    assert(Tut.handX(1) == Tut.coin.midX, "full, the hand is right on the wallet")
    assert(Tut.handX(2) == Tut.coin.midX, "and it never runs past it")
    assert(abs(Tut.handX(0.5) - (Tut.fill.minX + Tut.coin.midX) / 2) < 0.001, "half way, half way")
    // smooth all the way, no jump at the end
    var last = Tut.handX(0)
    for i in 1...100 {
        let x = Tut.handX(CGFloat(i) / 100)
        assert(x > last && x - last < 3, "the hand moves a little every step")
        last = x
    }
    #endif
}

// three strikes. one lights up every time you get spotted, all three and youre caught.
// a lit slot is Red/50 on Red/100, an unlit one Neutral/200 on Neutral/300 — it's the
// one meter on the screen that only ever moves against you, so it's never the yellow
// the steal bar uses.
struct SuspicionBar: View {
    let lit: Int
    let space: DesignSpace

    var body: some View {
        Group {
            place(Tut.inBar(Tut.suspOutline), space) { Image("tut_susp_outline").resizable() }
            place(Tut.inBar(Tut.suspBadge), space) { Image("tut_susp_badge").resizable() }
            ForEach(0..<Tut.slots, id: \.self) { i in
                slot(i)
            }
        }
    }

    private func slot(_ i: Int) -> some View {
        let on = i < lit
        let x = Tut.slotX + CGFloat(i) * (Tut.slot.width + Tut.slotGap)
        return place(Tut.inBar(CGRect(origin: CGPoint(x: x, y: Tut.slotY), size: Tut.slot)), space) {
            RoundedRectangle(cornerRadius: space.px(Tut.slotRadius))
                .fill(on ? Ink.redGlow : Ink.paper)
                .overlay(RoundedRectangle(cornerRadius: space.px(Tut.slotRadius))
                    .strokeBorder(on ? Ink.red : Ink.pale,
                                  lineWidth: space.px(Tut.slotBorder)))
        }
    }
}
