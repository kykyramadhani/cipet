import SwiftUI

// the red wash that stops play for a few seconds after somebody clocks you
struct PenaltyOverlay: View {
    let count: Int
    let space: DesignSpace

    private static let stopY:   CGFloat = 76
    private static let countY:  CGFloat = 122
    private static let noteY:   CGFloat = 166
    private static let stopSize:  CGFloat = 32
    private static let countSize: CGFloat = 64
    private static let noteSize:  CGFloat = 28

    var body: some View {
        ZStack {
            Ink.red.opacity(0.88).ignoresSafeArea()
            line("Stop for", Self.stopSize, Self.stopY)
            line("\(count)", Self.countSize, Self.countY)
            line("You almost get caught!", Self.noteSize, Self.noteY)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func line(_ text: String, _ size: CGFloat, _ y: CGFloat) -> some View {
        Text(text)
            .font(.skranji(space.px(size)))
            .foregroundStyle(.white)
            .contentTransition(.identity)
            .transaction { $0.animation = nil }
            .position(x: space.x(DesignSpace.screen.width / 2), y: space.y(y))
    }
}

// pause card. the model holds the round still, this is just the menu on top of it.
struct PausedCard: View {
    let space: DesignSpace
    let onResume: () -> Void

    private static let card  = CGRect(x: 300, y: 92, width: 274, height: 190)
    private static let title: CGFloat = 34
    private static let row   = CGSize(width: 214, height: 38)
    private static let rowGap: CGFloat = 10
    private static let rowSize: CGFloat = 22

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()

            VStack(spacing: space.px(Self.rowGap)) {
                Text("Paused")
                    .font(.skranji(space.px(Self.title)))
                    .foregroundStyle(Ink.black)
                    .padding(.bottom, space.px(2))
                button("Resume", filled: true, action: onResume)
                button("Main Menu", filled: false) {}
                button("Settings", filled: false) {}
            }
            .padding(space.px(16))
            .frame(width: space.px(Self.card.width))
            .background(Ink.paper, in: RoundedRectangle(cornerRadius: space.px(14)))
            .overlay(RoundedRectangle(cornerRadius: space.px(14))
                .stroke(.black, lineWidth: space.px(5)))
            .position(x: space.x(DesignSpace.screen.width / 2),
                      y: space.y(DesignSpace.screen.height / 2))
        }
    }

    private func button(_ title: String, filled: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.skranji(space.px(Self.rowSize), bold: false))
                .foregroundStyle(Ink.black)
                .frame(width: space.px(Self.row.width), height: space.px(Self.row.height))
                .background(filled ? Ink.yellow : Color.white,
                            in: RoundedRectangle(cornerRadius: space.px(9)))
                .overlay(RoundedRectangle(cornerRadius: space.px(9))
                    .stroke(.black, lineWidth: space.px(3)))
        }
        .buttonStyle(PressStyle())
    }
}
