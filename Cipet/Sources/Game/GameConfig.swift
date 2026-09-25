import SwiftUI

// everything is measured in the placeholder art's own pixel space, 2622x1206. the seats and
// characters are placed at native size so these numbers are literally where the sprites sit.

enum Bench {
    case far     // across the aisle, they face us
    case near    // our side, we see their backs
}

struct SeatSpec {
    let bench: Bench
    let seat: CGRect      // where the seat sprite goes
    let sitY: CGFloat     // baseline the feet rest on
}

enum Layout {
    static let scene  = CGSize(width: 2622, height: 1206)
    static let angkot = CGRect(x: 620, y: 87, width: 1307, height: 1036)

    // one tile covers the screen. the drawing is hand made and not periodic so the tile is cut
    // at 2557, the end of the last dark kerb block, where the pavement carries on dark -> light
    // and the dashed centre line matches the one on the left edge.
    static let roadTile   = scene
    static let roadPeriod: CGFloat = 2557
    static let roadX0:     CGFloat = 0

    // scenery, neither is playable, they just fill out the cabin
    static let foldingSeat = CGRect(x: 1304, y: 427, width: 160, height: 202)
    static let kid         = CGRect(x: 1270, y: 338, width: 182, height: 232)
    static let driver      = CGRect(x: 1516, y: 532, width: 216, height: 289)

    /// 7 usable seats, 3 far and 4 near. the folding one by the door is the kid's so it doesnt count.
    static let seats: [SeatSpec] = [
        .init(bench: .far,  seat: CGRect(x:  678, y: 258, width: 215, height: 262), sitY: 511),
        .init(bench: .far,  seat: CGRect(x:  864, y: 258, width: 215, height: 262), sitY: 511),
        .init(bench: .far,  seat: CGRect(x: 1050, y: 258, width: 215, height: 262), sitY: 511),
        .init(bench: .near, seat: CGRect(x:  684, y: 666, width: 235, height: 188), sitY: 784),
        .init(bench: .near, seat: CGRect(x:  870, y: 666, width: 235, height: 188), sitY: 784),
        .init(bench: .near, seat: CGRect(x: 1056, y: 666, width: 235, height: 188), sitY: 784),
        .init(bench: .near, seat: CGRect(x: 1242, y: 666, width: 235, height: 188), sitY: 784),
    ]

    /// in reach means same bench, next seat along. no reaching across the aisle.
    static func adjacent(_ a: Int, _ b: Int) -> Bool {
        abs(a - b) == 1 && seats[a].bench == seats[b].bench
    }
}

/// character sprites at native size so nothing gets stretched
enum Art {
    struct Sprite {
        let name: String
        let size: CGSize
        /// the pixels actually drawn inside `size`. the placeholder pngs have uneven transparent
        /// margins so badges and tap targets follow this, not the bitmap edges.
        let ink: CGRect
    }

    static let thief      = Sprite(name: "thief",
                                   size: CGSize(width: 163, height: 228),
                                   ink: CGRect(x: 5, y: 8, width: 153, height: 215))
    static let victimFar  = Sprite(name: "victim_far",
                                   size: CGSize(width: 160, height: 235),
                                   ink: CGRect(x: 0, y: 2, width: 158, height: 226))
    static let victimNear = Sprite(name: "victim_near",
                                   size: CGSize(width: 196, height: 243),
                                   ink: CGRect(x: 12, y: 25, width: 158, height: 207))

    static func victim(_ bench: Bench) -> Sprite { bench == .far ? victimFar : victimNear }
}

// every number we'd touch during playtesting lives here

enum Tune {
    static let round: Double = 60          // seconds
    static let roadSpeed: Double = 300     // scene units per second
    static let slideTime: Double = 0.3     // seat change animation
    static let awareDecay: Double = 0.40   // awareness lost per second when nobodys stealing
    static let moveSuspicion: Double = 0.20
    static let warnAwareness: Double = 0.30
    static let reach: CGFloat = 14         // how far he leans towards the seat hes robbing

    static let rideTime:  ClosedRange<Double> = 10...24   // how long somebody rides before getting off
    static let boardWait: ClosedRange<Double> = 1.5...5.0 // how long a seat stays empty
    static let maxPassengers = 4                          // leaves him at least two seats to move to
}

enum Kind: CaseIterable {
    case sleeper, doomscroller, chatterA, chatterB

    var config: Config {
        switch self {
        case .sleeper:
            return Config(busyTime: 5.0...8.0, alertTime: 2.0...3.5, wakeTime: 0.9,
                          awareBusy: 0.16, awareAlert: 0.75, stealTime: 2.2,
                          tint: Color(red: 0.72, green: 0.83, blue: 1.00), busySymbol: "zzz")
        case .doomscroller:
            return Config(busyTime: 4.0...7.0, alertTime: 1.5...2.5, wakeTime: 0.5,
                          awareBusy: 0.22, awareAlert: 0.95, stealTime: 1.9,
                          tint: Color(red: 1.00, green: 0.72, blue: 0.72), busySymbol: "iphone")
        case .chatterA, .chatterB:
            // fixed timings, not random, so the two of them stop chatting at the same moment
            return Config(busyTime: 6.0...6.0, alertTime: 3.0...3.0, wakeTime: 0.4,
                          awareBusy: 0.30, awareAlert: 1.05, stealTime: 2.6,
                          tint: self == .chatterA ? Color(red: 1.00, green: 0.90, blue: 0.64)
                                                  : Color(red: 0.75, green: 0.94, blue: 0.76),
                          busySymbol: "bubble.left.and.bubble.right.fill")
        }
    }
}

struct Config {
    let busyTime: ClosedRange<Double>
    let alertTime: ClosedRange<Double>
    let wakeTime: Double
    let awareBusy: Double
    let awareAlert: Double
    let stealTime: Double
    /// placeholder passengers are one blank sprite per bench, so the type is carried by a colour
    /// wash and the state by the badge over their head
    let tint: Color
    let busySymbol: String
}

enum Loot: CaseIterable {
    case wallet, bag
    var art: String { self == .wallet ? "wallet" : "bag" }
    var value: Int { self == .wallet ? 50 : 30 }     // thousands of rupiah
}
