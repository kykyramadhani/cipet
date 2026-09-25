import CoreHaptics

// the hold's buzz, on core haptics like the alerta app. UIImpactFeedbackGenerator was silent
// on the phone: it quietly does nothing when "System Haptics" is off, and core haptics doesnt.
// one tap, looped every holdInterval by the haptic server itself, so no timer on main.
enum Haptics {
    /// how hard each tap lands, 0...1. ~0.8 with the sharpness below reads as "medium".
    static let holdIntensity: Float = 0.8
    /// 0 is a dull thud, 1 a crisp click
    static let holdSharpness: Float = 0.5
    /// seconds between taps while the finger stays down (0.1 = 10 a second)
    static let holdInterval: TimeInterval = 0.1

    private static var engine: CHHapticEngine?
    private static var player: CHHapticAdvancedPatternPlayer?

    /// start the engine before the first hold, so the first tap isnt waiting on it
    static func warmUp() {
        guard engine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let e = try? CHHapticEngine() else { return }
        e.playsHapticsOnly = true            // stays out of the game's audio session
        e.isAutoShutdownEnabled = false
        // the system stops or resets it (backgrounding, a call); just bring it back
        e.stoppedHandler = { _ in try? e.start() }
        e.resetHandler = { try? e.start() }
        e.start { _ in }
        engine = e
    }

    /// the hand is in the pocket: a tap now, then one every holdInterval until stopHold
    static func startHold() {
        warmUp()
        stopHold()
        let tap = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: holdIntensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: holdSharpness),
        ], relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: [tap], parameters: []),
              let p = try? engine?.makeAdvancedPlayer(with: pattern) else { return }
        p.loopEnabled = true
        p.loopEnd = holdInterval
        try? p.start(atTime: CHHapticTimeImmediate)
        player = p
    }

    static func stopHold() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
    }
}
