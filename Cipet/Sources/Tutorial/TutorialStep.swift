import SwiftUI

struct TutorialStep {
    /// what each scene turns on
    struct Show: OptionSet {
        let rawValue: Int
        static let onPavement = Show(rawValue: 1 << 0)   // thief outside, plus his speech bubble
        static let seatGhosts = Show(rawValue: 1 << 1)   // the two faded "sit here" markers
        static let onBoard    = Show(rawValue: 1 << 2)   // thief seated on the far bench
        static let kid        = Show(rawValue: 1 << 3)
        static let stealBar   = Show(rawValue: 1 << 4)
        static let suspicion  = Show(rawValue: 1 << 5)
        static let awareness  = Show(rawValue: 1 << 6)
        static let alarm      = Show(rawValue: 1 << 9)   // clock goes red when time is nearly up
        /// only the scene that's actually teaching the suspicion bar lets it fill up
        static let counting   = Show(rawValue: 1 << 10)
    }

    let text: String
    let labelY: CGFloat
    let cardY: CGFloat
    let clock: String
    let show: Show
    /// whoever the thief is working on gets drawn in yellow
    var hot: Seating.Person? = nil

    var countsSuspicion: Bool { show.contains(.counting) }

    static let all: [TutorialStep] = [
        .init(text: "Choose your victim",
              labelY: 202, cardY: 199, clock: "1:30",
              show: [.onPavement]),
        .init(text: "Pick a seat to make your move",
              labelY: 200, cardY: 199, clock: "1:23",
              show: [.seatGhosts, .kid], hot: .near),
        .init(text: "Grab the item and keep your hand steady while stealing.",
              labelY: 196, cardY: 152, clock: "1:10",
              show: [.onBoard, .kid, .stealBar], hot: .farLeft),
        .init(text: "Watch out for other passengers\u{2019} suspicion bar.",
              labelY: 196, cardY: 153, clock: "1:10",
              show: [.onBoard, .kid, .suspicion, .awareness, .counting], hot: .farLeft),
        .init(text: "Grab the item before time runs out !",
              labelY: 196, cardY: 159, clock: "0:10",
              show: [.onBoard, .kid, .alarm, .stealBar, .suspicion, .awareness], hot: .farLeft),
    ]
}
