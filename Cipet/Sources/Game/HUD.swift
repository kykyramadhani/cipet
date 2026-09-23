import SwiftUI

struct HUD: View {
    @Binding var game: Game

    // 140x60 frame, 60x60 pause button, 40x40 icons. the hud_frame art is really 145x65 and
    // gets squeezed, the difference is too small to see. the text is what gives way:
    // minimumScaleFactor shrinks it when a number runs long.
    private static let top:    CGFloat = 20
    private static let side:   CGFloat = 24
    private static let frameW: CGFloat = 140
    private static let frameH: CGFloat = 60
    private static let pauseW: CGFloat = 60
    private static let icon:   CGFloat = 40
    private static let number: CGFloat = 40

    var body: some View {
        ZStack {
            loot.padding(.top, Self.top).padding(.leading, Self.side)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            timer.padding(.top, Self.top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            if game.phase == .play {
                pauseButton.padding(.top, Self.top).padding(.trailing, Self.side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            hint.padding(.bottom, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            switch game.phase {
            case .paused: pausedCard
            case .win, .caught: endingCard
            case .play: EmptyView()
            }
        }
    }

    private var loot: some View {
        panel {
            Image("hud_wallet").resizable().frame(width: Self.icon, height: Self.icon)
            // always two digits so the width stays put
            Text(String(format: "%02d", game.taken))
                .font(.skranji(Self.number, bold: false)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.identity)
                .transaction { $0.animation = nil }
        }
        .scaleEffect(game.flash != nil ? 1.1 : 1)   // pops when something is lifted
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: game.flash != nil)
    }

    private var timer: some View {
        let left = max(0, Int(game.time.rounded(.up)))
        let label = left >= 60 ? String(format: "%d:%02d", left / 60, left % 60) : "\(left)s"
        // never animate a number that changes every second, swiftui shows the old and the new
        // value at once and the timer looks doubled
        return panel {
            Image("hud_clock").resizable().frame(width: Self.icon, height: Self.icon)
            Text(label)
                .font(.skranji(Self.number, bold: false)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(left <= 15 ? .red : .black)
                .contentTransition(.identity)
                .animation(nil, value: game.time)
                .transaction { $0.animation = nil }
        }
    }

    private var pauseButton: some View {
        Button { game.togglePause() } label: {
            Image("hud_pause").resizable().frame(width: Self.pauseW, height: Self.frameH)
        }
        .buttonStyle(.plain)
    }

    private func panel<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 6) { content() }
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .frame(width: Self.frameW, height: Self.frameH)
            .background(Image("hud_frame").resizable())
    }

    private var hint: some View {
        Text("Hold the passenger next to you to rob them  ·  Tap an empty seat to move")
            .font(.skranji(13, bold: false))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.black.opacity(0.4), in: Capsule())
            .opacity(game.taken == 0 && game.phase == .play ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: game.taken)
    }

    private var pausedCard: some View {
        card {
            Text("PAUSED").font(.skranji(34)).foregroundStyle(.white)
            Text("The angkot is waiting for you.")
                .font(.skranji(14, bold: false))
                .foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 12) {
                pill("Resume", .yellow) { game.togglePause() }
                pill("Restart", .white.opacity(0.22), fg: .white) { game.restart() }
            }
            .padding(.top, 6)
        }
    }

    private var endingCard: some View {
        let won = game.phase == .win
        return card {
            Text(won ? "THIS IS MY STOP!" : "BUSTED!")
                .font(.skranji(34))
                .foregroundStyle(won ? .green : .red)
            Text(won ? "Clean getaway — you made it off the angkot." : "Somebody caught you in the act.")
                .font(.skranji(14, bold: false))
                .foregroundStyle(.white.opacity(0.8))
            Text("Rp \(game.score)k").font(.skranji(28)).foregroundStyle(.yellow)
            Text(game.taken == 1 ? "1 item lifted" : "\(game.taken) items lifted")
                .font(.skranji(14, bold: false))
                .foregroundStyle(.white.opacity(0.8))
            pill("Play Again", .yellow) { game.restart() }
                .padding(.top, 6)
        }
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 10) { content() }
                .padding(.horizontal, 44).padding(.vertical, 24)
                .background(Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.96),
                            in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.18), lineWidth: 2))
                .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
        }
    }

    private func pill(_ title: String, _ bg: Color, fg: Color = .black,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.skranji(18))
                .foregroundStyle(fg)
                .padding(.horizontal, 28).padding(.vertical, 10)
                .background(bg, in: Capsule())
        }
    }
}
