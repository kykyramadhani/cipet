import SwiftUI

// one passenger's suspicion, sat over their head. these stay at the level the scene shows.
struct AwarenessBar: View {
    let index: Int
    let space: DesignSpace

    var body: some View {
        let box  = Tut.aware[index]
        let fill = Tut.awareFill

        Group {
            place(Tut.inAngkot(Tut.centred(Tut.awareTrack.offsetBy(dx: box.minX, dy: box.minY),
                                           on: Tut.awareArt)), space) {
                Image("tut_aware_track").resizable()
            }
            place(Tut.inAngkot(CGRect(x: box.minX + fill.minX, y: box.minY + fill.minY,
                                      width: fill.width * Tut.awareLevel[index],
                                      height: fill.height)), space) {
                TwoToneBar(core: Ink.red, rim: Ink.redGlow,
                           radius: space.px(fill.height / 2), edge: space.px(1.4))
            }
            place(Tut.inAngkot(Tut.eye.offsetBy(dx: box.minX, dy: box.minY)), space) {
                Circle().fill(Color(white: 250 / 255))
                    .overlay(Circle().strokeBorder(Ink.black, lineWidth: space.px(1.429)))
                    .overlay {
                        Image("tut_eye").resizable()
                            .frame(width: space.px(Tut.eyeArt.width),
                                   height: space.px(Tut.eyeArt.height))
                    }
            }
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
                Text("Hold to fill the bar")
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
            place(Tut.inBar(CGRect(x: Tut.fill.minX + width - Tut.hand.width / 2, y: Tut.handY,
                                   width: Tut.hand.width, height: Tut.hand.height)), space) {
                Image("tut_hand").resizable()
            }
        }
    }
}

// three strikes. one lights up every time you get spotted, all three and youre caught.
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
                .fill(on ? Ink.yellow : Ink.paper)
                .overlay(RoundedRectangle(cornerRadius: space.px(Tut.slotRadius))
                    .strokeBorder(on ? Ink.glow : Ink.pale,
                                  lineWidth: space.px(Tut.slotBorder)))
        }
    }
}
