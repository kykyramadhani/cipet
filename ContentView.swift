import SwiftUI

// MARK: - Model (seat condition)

struct Seat: Identifiable {
    let id: Int
    let pos: CGPoint      // normalized (0...1) inside the cabin
    var occupied: Bool    // true = penumpang lain sudah duduk
}

struct Cabin {
    var seats: [Seat]
    var playerSeat: Int?

    /// Tap kursi: hanya bisa kalau kursinya kosong. Kursi lama dilepas.
    mutating func tap(_ id: Int) {
        guard let i = seats.firstIndex(where: { $0.id == id }), !seats[i].occupied else { return }
        if let old = playerSeat, let j = seats.firstIndex(where: { $0.id == old }) {
            seats[j].occupied = false
        }
        seats[i].occupied = true
        playerSeat = id
    }

    static let initial = Cabin(seats: [
        // baris atas (kiri)
        Seat(id: 0, pos: CGPoint(x: 0.29, y: 0.26), occupied: false),
        Seat(id: 1, pos: CGPoint(x: 0.41, y: 0.26), occupied: true),
        // baris bawah (kiri)
        Seat(id: 2, pos: CGPoint(x: 0.28, y: 0.79), occupied: false),
        Seat(id: 3, pos: CGPoint(x: 0.39, y: 0.79), occupied: true),
        Seat(id: 4, pos: CGPoint(x: 0.50, y: 0.79), occupied: false),
        Seat(id: 5, pos: CGPoint(x: 0.64, y: 0.79), occupied: false),
        // kursi tunggal (kanan / belakang sopir)
        Seat(id: 6, pos: CGPoint(x: 0.85, y: 0.26), occupied: true),
        Seat(id: 7, pos: CGPoint(x: 0.85, y: 0.78), occupied: false),
    ], playerSeat: nil)
}

// MARK: - View

struct ContentView: View {
    @State private var cabin = Cabin.initial

    private let door = CGPoint(x: 0.95, y: 0.52)   // posisi berdiri sebelum duduk
    private let seatSize = CGSize(width: 96, height: 76)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let point = { (p: CGPoint) in CGPoint(x: p.x * size.width, y: p.y * size.height) }

            ZStack {
                MovingBackground()                       // mekanik 2: angkot jalan

                ForEach(cabin.seats) { seat in           // mekanik 1: kondisi kursi
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color(for: seat))
                        .frame(width: seatSize.width, height: seatSize.height)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black, lineWidth: 2))
                        .position(point(seat.pos))
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.45)) { cabin.tap(seat.id) } }
                }

                Player()                                  // mekanik 3: gerak karakter
                    .position(point(cabin.playerSeat.flatMap { id in
                        cabin.seats.first { $0.id == id }?.pos
                    } ?? door))
            }
            .background(Color(red: 0.03, green: 0.13, blue: 0.29))
        }
        .ignoresSafeArea()
        .task { runChecks() }
    }

    private func color(for seat: Seat) -> Color {
        if seat.id == cabin.playerSeat { return .orange }
        return seat.occupied ? Color(white: 0.45) : Color(white: 0.78)
    }
}

/// Karakter: lingkaran kepala + badan. Ganti dengan asset SVG/PNG nanti.
struct Player: View {
    var body: some View {
        VStack(spacing: -6) {
            Circle().fill(Color(red: 1, green: 0.70, blue: 0.50)).frame(width: 30, height: 30)
            Capsule().fill(Color(red: 0.83, green: 0.48, blue: 0.52)).frame(width: 34, height: 36)
        }
        .shadow(radius: 4)
    }
}

/// Garis-garis jalan yang bergerak ke kiri — bikin kesan angkot melaju.
struct MovingBackground: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                let spacing: CGFloat = 160
                let speed: CGFloat = 220                                  // ponytail: kecepatan fix, jadikan @State kalau nanti butuh gas/rem
                let shift = CGFloat(t) * speed
                var x = -spacing + shift.truncatingRemainder(dividingBy: spacing)
                while x < size.width + spacing {
                    gc.fill(Path(CGRect(x: size.width - x, y: 0, width: 40, height: size.height)),
                            with: .color(.white.opacity(0.05)))
                    x += spacing
                }
            }
        }
    }
}

// MARK: - Check

private func runChecks() {
    #if DEBUG
    var c = Cabin.initial
    c.tap(1)                                   // kursi terisi -> ditolak
    assert(c.playerSeat == nil)
    c.tap(0)                                   // kursi kosong -> duduk
    assert(c.playerSeat == 0 && c.seats[0].occupied)
    c.tap(4)                                   // pindah kursi -> kursi lama kosong lagi
    assert(c.playerSeat == 4 && !c.seats[0].occupied && c.seats[4].occupied)
    #endif
}

#Preview { ContentView() }
