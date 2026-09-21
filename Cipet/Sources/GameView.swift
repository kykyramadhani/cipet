import SwiftUI

struct GameView: View {
    @State private var game = Game.new()
    private let clock = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            // Scene digambar di koordinat 1966.5x904.5 (viewBox asli art), lalu di-scale biar nutup layar.
            let s  = max(geo.size.width / Layout.scene.width, geo.size.height / Layout.scene.height)
            let ox = (geo.size.width  - Layout.scene.width  * s) / 2
            let oy = (geo.size.height - Layout.scene.height * s) / 2

            ZStack {
                RoadLayer(size: geo.size, s: s, ox: ox, oy: oy, roadX: game.roadX)

                CabinLayer(game: $game,
                           w: Layout.angkot.width * s,
                           h: Layout.angkot.height * s)
                    .position(x: ox + Layout.angkot.midX * s,
                              y: oy + Layout.angkot.midY * s)

                HUD(game: $game)
            }
            .background(.black)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onReceive(clock) { _ in game.tick(1.0 / 60) }
        // Model-nya tetap polos tanpa audio; view yang nyalain SFX pas state-nya berubah.
        .onChange(of: game.taken) { _, n in if n > 0 { Audio.shared.play(.success) } }
        .onChange(of: game.copet) { _, _ in Audio.shared.play(.move, volume: 0.55) }
        .onChange(of: game.phase) { _, p in
            if p == .caught { Audio.shared.play(.caught) }
            if p == .win    { Audio.shared.play(.win) }
        }
        .task { runGameChecks() }
    }
}

// MARK: - Jalan yang bergerak

struct RoadLayer: View {
    let size: CGSize
    let s: CGFloat, ox: CGFloat, oy: CGFloat
    let roadX: Double

    var body: some View {
        let tile   = CGSize(width: Layout.roadTile.width * s, height: Layout.roadTile.height * s)
        let period = Layout.roadPeriod * s
        let shift  = CGFloat(roadX.truncatingRemainder(dividingBy: Double(Layout.roadPeriod))) * s
        let count  = Int(ceil(size.width / period)) + 3

        ZStack(alignment: .topLeading) {
            Color(red: 0.36, green: 0.36, blue: 0.39)
            HStack(spacing: -(tile.width - period)) {           // tile-nya sengaja saling numpuk dikit
                ForEach(0..<count, id: \.self) { _ in
                    Image("road").resizable().frame(width: tile.width, height: tile.height)
                }
            }
            .offset(x: ox + Layout.roadX0 * s - shift - period, y: oy)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - Kabin: body angkot, lalu orang-orangnya, lalu UI kursi

struct CabinLayer: View {
    @Binding var game: Game
    let w: CGFloat, h: CGFloat

    private var charH: CGFloat { h * Tune.charH }

    var body: some View {
        Color.clear
            .frame(width: w, height: h)
            .overlay { Image("angkot").resizable().frame(width: w, height: h) }
            // urutan indeks = urutan gambar: bangku seberang dulu, bangku dekat nimpa di atasnya
            .overlay { ForEach(Layout.seats.indices, id: \.self) { seatSprite($0) } }
            .overlay { ForEach(Layout.seats.indices, id: \.self) { seatUI($0) } }
    }

    // MARK: Sprite

    @ViewBuilder private func seatSprite(_ i: Int) -> some View {
        let spec = Layout.seats[i]
        let y = h * spec.sitY - charH / 2

        if i == game.copet {
            let pose = copetPose(spec.bench)
            Image(pose.art).resizable().scaledToFit()
                .frame(height: charH)
                .scaleEffect(x: pose.flip ? -1 : 1)
                .position(x: spec.x * w, y: y)
                .animation(.easeOut(duration: Tune.slideTime), value: game.copet)
        } else if let p = game.seats[i] {
            Image(p.art(spec.bench)).resizable().scaledToFit()
                .frame(height: charH)
                .position(x: spec.x * w, y: y)
        }
    }

    /// Art `act` di folder karakter itu ngejangkau ke KIRI, jadi dicermin kalau targetnya di kanan.
    /// Bangku dekat belum punya art nyopet/geser, sementara pakai idle tampak belakang.
    private func copetPose(_ bench: Bench) -> (art: String, flip: Bool) {
        if bench == .near       { return ("copet_right_idle", false) }
        if game.slide > 0       { return (game.facing > 0 ? "copet_left_slide_right" : "copet_left_slide_left", false) }
        if !game.steals.isEmpty { return ("copet_left_act_left", game.facing > 0) }
        return ("copet_left_idle", false)
    }

    // MARK: UI per kursi + area tap

    @ViewBuilder private func seatUI(_ i: Int) -> some View {
        let spec = Layout.seats[i]
        let cx = spec.x * w
        let hitW = max(spec.w * w, 46)
        let headY = h * spec.sitY - charH
        let hitTop = min(headY - 4, h * spec.top)
        let hitH = max(h * spec.bottom - hitTop, 44)

        ZStack {
            if game.isEmpty(i) {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(.white, style: StrokeStyle(lineWidth: 3, dash: [7, 5]))
                    .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.35)))
                    .shadow(color: .black.opacity(0.35), radius: 3)
                    .frame(width: hitW, height: h * (spec.bottom - spec.top))
                    .position(x: cx, y: h * (spec.top + spec.bottom) / 2)
            }
            if let p = game.seats[i] {
                badges(p, i: i, cx: cx, top: headY - 6, barW: hitW)
            }
            Rectangle().fill(.clear).contentShape(Rectangle())
                .frame(width: hitW, height: hitH)
                .position(x: cx, y: hitTop + hitH / 2)
                .modifier(SeatInput(game: $game, seat: i))
        }
    }

    @ViewBuilder private func badges(_ p: Passenger, i: Int, cx: CGFloat, top: CGFloat, barW: CGFloat) -> some View {
        // Zzz di art aslinya berupa teks vektor dan nggak keikut waktu diekspor, jadi digambar di sini.
        if p.kind == .sleepy, p.state == .busy {
            Text("z Z")
                .font(.system(size: max(11, w * 0.022), weight: .black, design: .rounded))
                .foregroundStyle(.black.opacity(0.75))
                .rotationEffect(.degrees(-12))
                .offset(y: CGFloat(sin(game.clock * 2.2)) * 3)
                .position(x: cx + barW * 0.42, y: top + 10)
        }

        if let progress = game.steals[i] {                        // dua bar cuma muncul pas lagi dicopet
            VStack(spacing: 3) {
                Bar(value: progress,    tint: .green, width: barW)
                Bar(value: p.awareness, tint: .red,   width: barW)
            }
            .position(x: cx, y: top - 10)
        } else if p.awareness > Tune.warnAwareness {
            Text("!").font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.red)
                .shadow(color: .white, radius: 2)
                .position(x: cx, y: top - 6)
        }

        if p.loot == nil {                                        // barangnya udah diambil
            Text("✓").font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white).padding(3)
                .background(.green.opacity(0.85), in: Circle())
                .position(x: cx + barW * 0.34, y: top + 2)
        }

        if let f = game.flash, f.seat == i {
            let t = CGFloat(1 - f.life)                       // 0 -> 1 sepanjang animasi

            Circle()                                          // cincin meletus di badan korban
                .stroke(.white.opacity(Double(1 - t) * 0.85), lineWidth: 4 * (1 - t) + 1)
                .frame(width: barW * (0.6 + t * 1.9), height: barW * (0.6 + t * 1.9))
                .position(x: cx, y: top + charH * 0.45)

            Image(f.loot).resizable().scaledToFit()           // barangnya melayang keluar
                .frame(height: charH * 0.46)
                .scaleEffect(0.6 + (1 - t) * 0.65)
                .rotationEffect(.degrees(Double(t) * 22))
                .shadow(color: .black.opacity(0.45), radius: 3)
                .position(x: cx, y: top + charH * 0.45 - t * charH * 0.85)
                .opacity(Double(1 - t * t))

            Text(f.text).font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .shadow(color: .black, radius: 3)
                .position(x: cx + barW * 0.5, y: top + 2 - t * 30)
                .opacity(f.life)
        }
    }
}

/// Kursi kosong = tap buat pindah. Kursi berpenumpang = tahan buat nyopet, lepas buat batal.
struct SeatInput: ViewModifier {
    @Binding var game: Game
    let seat: Int

    func body(content: Content) -> some View {
        if game.isEmpty(seat) {
            content.onTapGesture { game.move(to: seat) }
        } else if game.seats[seat] != nil {
            // simultaneousGesture, bukan gesture: biar dua kursi bisa ditahan barengan
            content.simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in game.beginSteal(seat) }
                    .onEnded   { _ in game.endSteal(seat) }
            )
        } else {
            content
        }
    }
}

struct Bar: View {
    let value: Double, tint: Color, width: CGFloat
    var body: some View {
        Capsule().fill(.black.opacity(0.55))
            .frame(width: width, height: 7)
            .overlay(alignment: .leading) {
                Capsule().fill(tint).frame(width: width * CGFloat(min(1, max(0, value))), height: 7)
            }
            .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1))
    }
}

#Preview(traits: .landscapeLeft) { GameView() }
