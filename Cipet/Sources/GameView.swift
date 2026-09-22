import SwiftUI

struct GameView: View {
    @State private var game = Game.new()
    private let clock = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            // The scene is drawn in the placeholder art's own pixel space (2622x1206, the size of
            // Jalan.png and Benchmark.png) and then scaled once to cover the screen.
            let s  = max(geo.size.width / Layout.scene.width, geo.size.height / Layout.scene.height)
            let ox = (geo.size.width  - Layout.scene.width  * s) / 2
            let oy = (geo.size.height - Layout.scene.height * s) / 2

            ZStack {
                RoadLayer(size: geo.size, s: s, ox: ox, oy: oy, roadX: game.roadX)
                CabinLayer(game: $game, s: s, ox: ox, oy: oy)
                HUD(game: $game)
            }
            .background(.black)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onReceive(clock) { _ in game.tick(1.0 / 60) }
        // The model stays audio-free; the view is what fires SFX when its state changes.
        .onChange(of: game.taken) { _, n in if n > 0 { Audio.shared.play(.success) } }
        .onChange(of: game.thief) { _, _ in Audio.shared.play(.move, volume: 0.55) }
        .onChange(of: game.phase) { _, p in
            if p == .caught { Audio.shared.play(.caught) }
            if p == .win    { Audio.shared.play(.win) }
        }
        .task { runGameChecks() }
    }
}

// MARK: - Scrolling road

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
            Color(white: 163.0 / 255)                            // the base grey of Jalan.png
            HStack(spacing: -(tile.width - period)) {            // tiles deliberately overlap a little
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

// MARK: - Cabin: bus body, scenery, seats, people, then the seat UI
//
// Draw order is the one Benchmark.png is built in: far seats, far passengers, folding seat and
// the kid on it, near seats, near passengers, driver.

struct CabinLayer: View {
    @Binding var game: Game
    let s: CGFloat, ox: CGFloat, oy: CGFloat

    var body: some View {
        ZStack {
            sprite("angkot", Layout.angkot)

            ForEach(farSeats,  id: \.self) { sprite("seat_far",  Layout.seats[$0].seat) }
            ForEach(farSeats,  id: \.self) { passenger($0) }

            sprite("seat_folding", Layout.foldingSeat)
            sprite("kid", Layout.kid)

            ForEach(nearSeats, id: \.self) { sprite("seat_near", Layout.seats[$0].seat) }
            ForEach(nearSeats, id: \.self) { passenger($0) }

            sprite("driver", Layout.driver)

            thief
            ForEach(Layout.seats.indices, id: \.self) { seatUI($0) }
        }
        .frame(width: Layout.scene.width * s, height: Layout.scene.height * s)
        .position(x: ox + Layout.scene.width * s / 2, y: oy + Layout.scene.height * s / 2)
    }

    private var farSeats:  [Int] { Layout.seats.indices.filter { Layout.seats[$0].bench == .far } }
    private var nearSeats: [Int] { Layout.seats.indices.filter { Layout.seats[$0].bench == .near } }

    /// Places a sprite at its scene rect, at native size — no stretching anywhere.
    private func sprite(_ name: String, _ r: CGRect) -> some View {
        Image(name).resizable()
            .frame(width: r.width * s, height: r.height * s)
            .position(x: r.midX * s, y: r.midY * s)
    }

    /// Where a seated character's sprite sits: centred on the seat, feet on `sitY`.
    private func charRect(_ i: Int, _ a: Art.Sprite) -> CGRect {
        let spec = Layout.seats[i]
        return CGRect(x: spec.seat.midX - a.size.width / 2, y: spec.sitY - a.size.height,
                      width: a.size.width, height: a.size.height)
    }

    /// Same, but only the pixels that are actually drawn — what badges and tap targets hang off.
    private func inkRect(_ i: Int, _ a: Art.Sprite) -> CGRect {
        let r = charRect(i, a)
        return CGRect(x: r.minX + a.ink.minX, y: r.minY + a.ink.minY,
                      width: a.ink.width, height: a.ink.height)
    }

    // MARK: Sprites

    @ViewBuilder private func passenger(_ i: Int) -> some View {
        if i != game.thief, let p = game.seats[i] {
            let art = Art.victim(Layout.seats[i].bench)
            sprite(art.name, charRect(i, art))
                // One blank sprite per bench, so the archetype is carried by a colour wash.
                .colorMultiply(p.kind.config.tint)
                .saturation(p.state == .shock ? 0 : 1)
        }
    }

    /// Only one thief sprite exists, so it is drawn once and slid between seats. The lean towards
    /// the seat being robbed is what replaces the old reaching pose.
    private var thief: some View {
        let r = charRect(game.thief, Art.thief)
        let lean = game.steals.isEmpty ? 0 : CGFloat(game.facing) * Tune.reach
        return sprite(Art.thief.name, r.offsetBy(dx: lean, dy: 0))
            .animation(.easeOut(duration: Tune.slideTime), value: game.thief)
            .animation(.easeOut(duration: 0.12), value: game.steals.isEmpty)
    }

    // MARK: Per-seat UI and tap targets

    @ViewBuilder private func seatUI(_ i: Int) -> some View {
        let spec = Layout.seats[i]
        let art  = Art.victim(spec.bench)
        let body = inkRect(i, art)
        let hit  = spec.seat.union(body)                 // the near bench sits below its passenger

        ZStack {
            if game.isEmpty(i) {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(.white, style: StrokeStyle(lineWidth: 3, dash: [7, 5]))
                    .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.35)))
                    .shadow(color: .black.opacity(0.35), radius: 3)
                    .frame(width: spec.seat.width * s, height: spec.seat.height * s)
                    .position(x: spec.seat.midX * s, y: spec.seat.midY * s)
            }
            if let p = game.seats[i], i != game.thief {
                badges(p, i: i, cx: body.midX * s, headY: body.minY * s,
                       barW: body.width * s, bodyH: body.height * s)
            }
            Rectangle().fill(.clear).contentShape(Rectangle())
                .frame(width: max(hit.width * s, 46), height: max(hit.height * s, 44))
                .position(x: hit.midX * s, y: hit.midY * s)
                .modifier(SeatInput(game: $game, seat: i))
        }
    }

    @ViewBuilder private func badges(_ p: Passenger, i: Int, cx: CGFloat, headY: CGFloat,
                                     barW: CGFloat, bodyH: CGFloat) -> some View {
        // The placeholder passengers have no per-state drawing, so the state is spelled out here.
        Image(systemName: stateSymbol(p))
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(stateColor(p))
            .frame(width: 15, height: 15)
            .padding(4)
            .background(.white.opacity(0.92), in: Circle())
            .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 1))
            .offset(y: p.state == .busy ? CGFloat(sin(game.clock * 2.2)) * 3 : 0)
            .position(x: cx + barW * 0.5, y: headY + 8)

        if let progress = game.steals[i] {                        // both bars only show mid-robbery
            VStack(spacing: 3) {
                Bar(value: progress,    tint: .green, width: barW)
                Bar(value: p.awareness, tint: .red,   width: barW)
            }
            .position(x: cx, y: headY - 14)
        } else if p.awareness > Tune.warnAwareness {
            Text("!").font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.red)
                .shadow(color: .white, radius: 2)
                .position(x: cx, y: headY - 10)
        }

        if p.loot == nil {                                        // already cleaned out
            Text("✓").font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white).padding(3)
                .background(.green.opacity(0.85), in: Circle())
                .position(x: cx - barW * 0.5, y: headY + 8)
        }

        if let f = game.flash, f.seat == i {
            let t = CGFloat(1 - f.life)                       // 0 -> 1 across the animation
            let h = bodyH

            Circle()                                          // ring bursting off the victim
                .stroke(.white.opacity(Double(1 - t) * 0.85), lineWidth: 4 * (1 - t) + 1)
                .frame(width: barW * (0.6 + t * 1.9), height: barW * (0.6 + t * 1.9))
                .position(x: cx, y: headY + h * 0.45)

            Image(f.loot).resizable().scaledToFit()           // the item floating away
                .frame(height: h * 0.46)
                .scaleEffect(0.6 + (1 - t) * 0.65)
                .rotationEffect(.degrees(Double(t) * 22))
                .shadow(color: .black.opacity(0.45), radius: 3)
                .position(x: cx, y: headY + h * 0.45 - t * h * 0.85)
                .opacity(Double(1 - t * t))

            Text(f.text).font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .shadow(color: .black, radius: 3)
                .position(x: cx + barW * 0.5, y: headY - t * 30)
                .opacity(f.life)
        }
    }

    private func stateSymbol(_ p: Passenger) -> String {
        switch p.state {
        case .busy:   return p.kind.config.busySymbol
        case .waking: return "eye"
        case .alert:  return "eye.fill"
        case .shock:  return "exclamationmark.triangle.fill"
        }
    }

    private func stateColor(_ p: Passenger) -> Color {
        switch p.state {
        case .busy:   return .black.opacity(0.7)
        case .waking: return .orange
        case .alert, .shock: return .red
        }
    }
}

/// Empty seat = tap to move there. Occupied seat = hold to rob, let go to abort.
struct SeatInput: ViewModifier {
    @Binding var game: Game
    let seat: Int

    func body(content: Content) -> some View {
        if game.isEmpty(seat) {
            content.onTapGesture { game.move(to: seat) }
        } else if game.seats[seat] != nil {
            // simultaneousGesture, not gesture: so two seats can be held at the same time
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
