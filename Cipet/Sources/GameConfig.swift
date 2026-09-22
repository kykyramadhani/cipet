import SwiftUI

// MARK: - Layout
// Angka di sini diukur dari environment/angkot.svg (viewBox 1966.5 x 904.5). Jalan sekarang
// pakai Placeholder/Jalan.png yang rasionya sama, jadi tetap ditumpuk di ruang koordinat itu.

enum Bench {
    case far     // bangku seberang: penumpang kelihatan dari depan (art *_left_*)
    case near    // bangku dekat: kelihatan dari belakang (art *_right_*)
}

struct SeatSpec {
    let bench: Bench
    let x: CGFloat        // titik tengah kursi, 0...1 relatif lebar gambar angkot
    let w: CGFloat        // lebar kursi
    let top: CGFloat      // batas atas jok (buat penanda kursi kosong + area tap)
    let bottom: CGFloat   // batas bawah jok
    let sitY: CGFloat     // garis bawah sprite orang yang duduk di kursi ini
}

enum Layout {
    static let scene  = CGSize(width: 1966.5, height: 904.5)
    static let angkot = CGRect(x: 411.02, y: 47.39, width: 1146.05, height: 826.21)

    // Jalan pakai Placeholder/Jalan.png (2622x1206) — rasionya sama persis dengan scene, jadi
    // satu tile = satu layar. Gambarnya tangan, nggak periodik; tile-nya dipotong di x=2557 px
    // (ujung blok gelap trotoar terakhir) supaya sambungannya mulus: trotoar lanjut gelap->terang
    // dan garis putus-putus di ujung kanan nyambung sama yang di ujung kiri.
    static let roadTile   = CGSize(width: 1966.5, height: 904.5)
    static let roadPeriod: CGFloat = 2557 * (904.5 / 1206)
    static let roadX0:     CGFloat = 0

    /// 9 kursi hijau. Posisi diambil dari hasil scan pixel hijau di art, bukan kira-kira.
    /// Bangku seberang: 4 jok + 1 kursi lipat dekat pintu, masing-masing 1 orang.
    /// Bangku dekat: 2 jok hijau lebar, masing-masing muat 2 orang -> 4 orang.
    static let seats: [SeatSpec] = [
        .init(bench: .far,  x: 0.179, w: 0.088, top: 0.259, bottom: 0.417, sitY: 0.455),
        .init(bench: .far,  x: 0.271, w: 0.088, top: 0.259, bottom: 0.417, sitY: 0.455),
        .init(bench: .far,  x: 0.364, w: 0.088, top: 0.259, bottom: 0.417, sitY: 0.455),
        .init(bench: .far,  x: 0.459, w: 0.088, top: 0.259, bottom: 0.417, sitY: 0.455),
        .init(bench: .far,  x: 0.599, w: 0.088, top: 0.259, bottom: 0.417, sitY: 0.455),
        .init(bench: .near, x: 0.162, w: 0.082, top: 0.532, bottom: 0.610, sitY: 0.638),
        .init(bench: .near, x: 0.246, w: 0.082, top: 0.532, bottom: 0.610, sitY: 0.638),
        .init(bench: .near, x: 0.340, w: 0.082, top: 0.532, bottom: 0.610, sitY: 0.638),
        .init(bench: .near, x: 0.433, w: 0.082, top: 0.532, bottom: 0.610, sitY: 0.638),
    ]

    /// Bersebelahan = satu bangku dan nomornya nempel. Beda bangku nggak bisa saling jangkau.
    static func adjacent(_ a: Int, _ b: Int) -> Bool {
        abs(a - b) == 1 && seats[a].bench == seats[b].bench
    }
}

// MARK: - Balancing
// Semua angka yang bakal diubah-ubah waktu playtest ngumpul di sini.

enum Tune {
    static let round: Double = 90          // durasi ronde (detik)
    static let roadSpeed: Double = 300     // unit scene per detik
    static let slideTime: Double = 0.3     // animasi geser kursi
    static let awareDecay: Double = 0.40   // awareness turun per detik kalau nggak dicopet
    static let moveSuspicion: Double = 0.20
    static let warnAwareness: Double = 0.30

    static let rideTime:  ClosedRange<Double> = 10...24   // lama penumpang ikut angkot sebelum turun
    static let boardWait: ClosedRange<Double> = 1.5...5.0 // kursi kosong nganggur sebelum ada yang naik
    static let maxPassengers = 5                          // sisanya dibiarin kosong biar copet bisa pindah

    static let charH: CGFloat = 0.215      // tinggi sprite relatif tinggi angkot
}

// MARK: - Archetype (data-driven)

enum Kind: CaseIterable {
    case sleepy, doom, duoA, duoB

    var config: Config {
        switch self {
        case .sleepy:
            return Config(busy: "sleepy_left_sleeping", waking: "sleepy_left_wakeup",
                          alert: "sleepy_left_aware",   shock: "sleepy_left_shock",
                          busyTime: 5.0...8.0, alertTime: 2.0...3.5, wakeTime: 0.9,
                          awareBusy: 0.16, awareAlert: 0.75, stealTime: 2.2)
        case .doom:
            return Config(busy: "doomscrollings_left_active", waking: "doomscrollings_left_active",
                          alert: "doomscrollings_left_aware", shock: "doomscrollings_left_shock",
                          busyTime: 4.0...7.0, alertTime: 1.5...2.5, wakeTime: 0.5,
                          awareBusy: 0.22, awareAlert: 0.95, stealTime: 1.9)
        case .duoA, .duoB:
            let n = self == .duoA ? "duoA" : "duoB"
            return Config(busy: "\(n)_left_talking", waking: "\(n)_left_idle",
                          alert: "\(n)_left_idle",   shock: "\(n)_left_idle",
                          busyTime: 6.0...6.0, alertTime: 3.0...3.0, wakeTime: 0.4,
                          awareBusy: 0.30, awareAlert: 1.05, stealTime: 2.6)
        }
    }

    /// Bangku dekat butuh art tampak belakang. Duo belum punya, jadi mereka nggak pernah duduk di situ.
    var hasBackArt: Bool { self == .sleepy || self == .doom }

    func art(_ state: PState, bench: Bench) -> String {
        guard bench == .near else {
            switch state {
            case .busy:   return config.busy
            case .waking: return config.waking
            case .alert:  return config.alert
            case .shock:  return config.shock
            }
        }
        if self == .sleepy { return state == .busy ? "sleepy_right_sleeping" : "sleepy_right_idle" }
        return "doomscrollings_right_active"
    }
}

struct Config {
    let busy: String, waking: String, alert: String, shock: String
    let busyTime: ClosedRange<Double>
    let alertTime: ClosedRange<Double>
    let wakeTime: Double
    let awareBusy: Double
    let awareAlert: Double
    let stealTime: Double
}

enum Loot: CaseIterable {
    case wallet, bag
    var art: String { self == .wallet ? "wallet" : "bag" }
    var value: Int { self == .wallet ? 50 : 30 }     // ribuan rupiah
}
