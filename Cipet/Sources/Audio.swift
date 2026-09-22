import AVFoundation

/// Placeholder SFX — the WAV files are generated, just drop the real audio on top later.
/// The filenames in Resources/Audio must match the cases below exactly.
enum SFX: String, CaseIterable {
    case success = "sfx_success"
    case caught  = "sfx_caught"
    case move    = "sfx_move"
    case win     = "sfx_win"
}

final class Audio {
    static let shared = Audio()

    private var pool: [SFX: [AVAudioPlayer]] = [:]
    private var next: [SFX: Int] = [:]
    private static let voices = 3            // so the same sound can overlap itself

    private init() {
        // .ambient: respects the silent switch and does not cut the player's own music
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        for sfx in SFX.allCases {
            guard let url = Bundle.main.url(forResource: sfx.rawValue, withExtension: "wav") else { continue }
            pool[sfx] = (0..<Self.voices).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
            next[sfx] = 0
        }
    }

    func play(_ sfx: SFX, volume: Float = 1) {
        guard let voices = pool[sfx], !voices.isEmpty else { return }
        let i = (next[sfx] ?? 0) % voices.count
        next[sfx] = i + 1
        let p = voices[i]
        p.volume = volume
        p.currentTime = 0
        p.play()
    }
}
