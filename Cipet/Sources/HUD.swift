import SwiftUI

struct HUD: View {
    @Binding var game: Game

    var body: some View {
        ZStack {
            // Layout dari desain (kanvas 874x402): frame 140x60 di top 20, wallet left 24,
            // clock left 367 (= pas di tengah), pause 60x60 nempel kanan dengan margin yang sama.
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

    // MARK: Bar atas
    //
    // Ukuran ngikutin desain: frame 140x60, tombol pause 60x60, ikon 40x40. Art `hud_frame`
    // aslinya 145x65 jadi ditarik dikit ke 140x60 — beda rasionya kecil, nggak kelihatan.
    // Teks yang ngalah: nyusut lewat `minimumScaleFactor` kalau angkanya kepanjangan.

    private static let top:    CGFloat = 20
    private static let side:   CGFloat = 24
    private static let frameW: CGFloat = 140
    private static let frameH: CGFloat = 60
    private static let pauseW: CGFloat = 60
    private static let icon:   CGFloat = 40
    private static let number: CGFloat = 40                      // angka di dalam frame, Skranji Regular

    private var loot: some View {
        panel {
            Image("hud_wallet").resizable().frame(width: Self.icon, height: Self.icon)
            // Jumlah barang yang berhasil dicopet, selalu dua digit ("00", "07") biar lebarnya stabil.
            Text(String(format: "%02d", game.taken))
                .font(.skranji(Self.number, bold: false)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.identity)
                .transaction { $0.animation = nil }              // angkanya jangan ikut dianimasiin
        }
        .scaleEffect(game.flash != nil ? 1.1 : 1)                // nyentak pas dapat barang
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: game.flash != nil)
    }

    private var timer: some View {
        let left = max(0, Int(game.time.rounded(.up)))
        // Di atas semenit pakai m:ss, di bawah itu detik polos.
        let label = left >= 60 ? String(format: "%d:%02d", left / 60, left % 60) : "\(left)s"
        // Jangan kasih animasi ke angka yang ganti tiap detik — kalau dianimasiin, SwiftUI
        // nampilin angka lama dan angka baru barengan (ini yang bikin timernya keliatan dobel).
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
            Image("hud_pause").resizable()
                .frame(width: Self.pauseW, height: Self.frameH)
        }
        .buttonStyle(.plain)
    }

    /// Frame putih bergaris tangan + isi di tengahnya.
    private func panel<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 6) { content() }
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .frame(width: Self.frameW, height: Self.frameH)
            .background(Image("hud_frame").resizable())
    }

    private var hint: some View {
        Text("Tahan penumpang sebelah buat nyopet  ·  Tap kursi kosong buat pindah")
            .font(.skranji(13, bold: false))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.black.opacity(0.4), in: Capsule())
            .opacity(game.taken == 0 && game.phase == .play ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: game.taken)
    }

    // MARK: Layar tumpang

    private var pausedCard: some View {
        card {
            Text("JEDA").font(.skranji(34))
                .foregroundStyle(.white)
            Text("Angkotnya nungguin kamu.")
                .font(.skranji(14, bold: false))
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
                .font(.skranji(34))
                .foregroundStyle(won ? .green : .red)
            Text(won ? "Selamat, lolos sampai turun." : "Ada yang mergokin kamu.")
                .font(.skranji(14, bold: false))
                .foregroundStyle(.white.opacity(0.8))
            Text("Rp \(game.score) ribu")
                .font(.skranji(28))
                .foregroundStyle(.yellow)
            Text("\(game.taken) barang berhasil dicopet")
                .font(.skranji(14, bold: false))
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
                .font(.skranji(18))
                .foregroundStyle(fg)
                .padding(.horizontal, 28).padding(.vertical, 10)
                .background(bg, in: Capsule())
        }
    }
}

// MARK: - Font

extension Font {
    /// Skranji (Resources/Fonts, OFL) — font tulisan tangan buat semua teks HUD.
    /// Nama PostScript-nya `Skranji` (regular, BUKAN "Skranji-Regular") dan `Skranji-Bold`,
    /// didaftarin lewat `UIAppFonts`. Salah nama = diam-diam jatuh ke font sistem.
    static func skranji(_ size: CGFloat, bold: Bool = true) -> Font {
        .custom(bold ? "Skranji-Bold" : "Skranji", size: size)
    }
}
