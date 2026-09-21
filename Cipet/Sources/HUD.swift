import SwiftUI

struct HUD: View {
    @Binding var game: Game

    var body: some View {
        ZStack {
            VStack {
                ZStack {
                    timer                                        // ditaruh di ZStack biar bener-bener di tengah
                    HStack {
                        loot
                        Spacer()
                        if game.phase == .play { pauseButton }
                    }
                }
                Spacer()
                hint
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)

            switch game.phase {
            case .paused: pausedCard
            case .win, .caught: endingCard
            case .play: EmptyView()
            }
        }
    }

    // MARK: Bar atas

    private var loot: some View {
        HStack(spacing: 7) {
            Image("wallet").resizable().scaledToFit().frame(height: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text("Rp \(game.score) rb").font(.system(size: 17, weight: .black, design: .rounded))
                Text("\(game.taken) barang").font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .contentTransition(.identity)
            .transaction { $0.animation = nil }                  // angkanya jangan ikut dianimasiin
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.black.opacity(0.45), in: Capsule())
        .scaleEffect(game.flash != nil ? 1.1 : 1)                // nyentak pas dapat barang
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: game.flash != nil)
    }

    private var timer: some View {
        let left = max(0, Int(game.time.rounded(.up)))
        // Di atas semenit pakai m:ss, di bawah itu detik polos.
        let label = left >= 60 ? String(format: "%d:%02d", left / 60, left % 60) : "\(left)s"
        // Jangan kasih animasi ke angka yang ganti tiap detik — kalau dianimasiin, SwiftUI
        // nampilin angka lama dan angka baru barengan (ini yang bikin timernya keliatan dobel).
        return Text(label)
            .font(.system(size: 26, weight: .black, design: .rounded)).monospacedDigit()
            .foregroundStyle(left <= 15 ? .red : .white)
            .contentTransition(.identity)
            .animation(nil, value: game.time)
            .transaction { $0.animation = nil }
            .padding(.horizontal, 16).padding(.vertical, 5)
            .background(.black.opacity(0.45), in: Capsule())
    }

    private var pauseButton: some View {
        Button { game.togglePause() } label: {
            Image(systemName: "pause.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.black.opacity(0.45), in: Circle())
        }
    }

    private var hint: some View {
        Text("Tahan penumpang sebelah buat nyopet  ·  Tap kursi kosong buat pindah")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.black.opacity(0.4), in: Capsule())
            .opacity(game.taken == 0 && game.phase == .play ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: game.taken)
    }

    // MARK: Layar tumpang

    private var pausedCard: some View {
        card {
            Text("JEDA").font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Angkotnya nungguin kamu.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 12) {
                pill("Lanjut", .yellow) { game.togglePause() }
                pill("Ulangi", .white.opacity(0.22), fg: .white) { game.restart() }
            }
            .padding(.top, 6)
        }
    }

    private var endingCard: some View {
        let won = game.phase == .win
        return card {
            Text(won ? "TURUN, BANG!" : "KETAHUAN!")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(won ? .green : .red)
            Text(won ? "Selamat, lolos sampai turun." : "Ada yang mergokin kamu.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            Text("Rp \(game.score) ribu")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
            Text("\(game.taken) barang berhasil dicopet")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            pill("Main Lagi", .yellow) { game.restart() }
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

    private func pill(_ title: String, _ bg: Color, fg: Color = .black, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(fg)
                .padding(.horizontal, 28).padding(.vertical, 10)
                .background(bg, in: Capsule())
        }
    }
}
