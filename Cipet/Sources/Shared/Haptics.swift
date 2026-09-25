import UIKit

// the taptic engine takes a moment to spin up, so the generator is kept around and warmed
// before the hand goes in — prepared late and the first tick of a hold arrives after it.
enum Haptics {
    /// how hard each tick of a hold lands, 0...1 on the medium generator. turn this one.
    static let holdIntensity: CGFloat = 0.8
    /// seconds between ticks while the finger stays down (0.1 = 10 a second)
    static let holdInterval: TimeInterval = 0.1

    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static var holdTimer: Timer?

    /// call when a hold is about to become possible, so the first one lands on time
    static func warmUp() { medium.prepare() }

    /// the hand is in the pocket: one tick now, then one every holdInterval until stopHold
    static func startHold() {
        stopHold()
        tick()
        let t = Timer(timeInterval: holdInterval, repeats: true) { _ in tick() }
        RunLoop.main.add(t, forMode: .common)   // keeps ticking while touches are being tracked
        holdTimer = t
    }

    static func stopHold() {
        holdTimer?.invalidate()
        holdTimer = nil
    }

    private static func tick() {
        medium.impactOccurred(intensity: holdIntensity)
        medium.prepare()
    }
}
