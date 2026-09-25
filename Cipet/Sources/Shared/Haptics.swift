import UIKit

// the taptic engine takes a moment to spin up, so the generator is kept around and warmed
// before the hand goes in — prepared late and the first tap of a round arrives after it.
enum Haptics {
    private static let soft = UIImpactFeedbackGenerator(style: .soft)

    /// call when a hold is about to become possible, so the first one lands on time
    static func warmUp() { soft.prepare() }

    /// the thief's hand closing on somebody's pocket
    static func grab() {
        soft.impactOccurred()
        soft.prepare()   // he'll most likely let go and try again
    }
}
