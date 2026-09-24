import SwiftUI

// the coach card. skip and next are the only things on this screen you can touch.
struct TutorialCard: View {
    let text: String
    let nextTitle: String
    let space: DesignSpace
    let onSkip: () -> Void
    let onNext: () -> Void

    var body: some View {
        // the inner width is stated rather than left to maxWidth infinity. otherwise the button
        // row gets the full width and the sentence gets a narrower one, and it wraps a word early.
        let inner = space.px(Tut.cardW - 2 * Tut.cardPad)

        VStack(alignment: .leading, spacing: space.px(Tut.cardGap)) {
            Text(text)
                .font(.skranji(space.px(Tut.cardSize), bold: false))
                .foregroundStyle(Ink.black)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: inner, alignment: .leading)

            HStack(alignment: .top, spacing: 0) {
                skip
                Spacer(minLength: space.px(8))
                next
            }
            .frame(width: inner)
        }
        .padding(space.px(Tut.cardPad))
        .background(Ink.paper, in: RoundedRectangle(cornerRadius: space.px(Tut.cardRadius)))
        // the border is centred on the card's edge so it hangs half outside — stroke, not
        // strokeBorder, which would keep all of it inside the bounds
        .overlay(RoundedRectangle(cornerRadius: space.px(Tut.cardRadius))
            .stroke(.black, lineWidth: space.px(Tut.cardBorder)))
    }

    private var skip: some View {
        Button(action: onSkip) {
            Text("Skip")
                .font(.skranji(space.px(Tut.skipSize), bold: false))
                .foregroundStyle(Ink.black)
                .underline()
                .padding(space.px(10))       // fatter tap target, same ink
                .contentShape(Rectangle())
        }
        .padding(space.px(-10))
    }

    private var next: some View {
        Button(action: onNext) {
            ZStack(alignment: .topLeading) {
                Image("tut_next").resizable()
                    .frame(width: space.px(Tut.nextArt.width),
                           height: space.px(Tut.nextArt.height))
                    .offset(x: space.px(Tut.nextNudge.width), y: space.px(Tut.nextNudge.height))
                Text(nextTitle)
                    .font(.skranji(space.px(Tut.nextSize), bold: false))
                    .foregroundStyle(Ink.soft)
                    .frame(width: space.px(Tut.nextBox.width), height: space.px(Tut.nextBox.height))
                    .offset(x: space.px(-5), y: space.px(-2.5))
            }
            .frame(width: space.px(Tut.nextBox.width),
                   height: space.px(Tut.nextBox.height), alignment: .topLeading)
            .padding(space.px(12))
            .contentShape(Rectangle())
            .padding(space.px(-12))
        }
        .buttonStyle(PressStyle())
    }
}
