import AVFoundation

/// filenames in Resources/Audio have to match these exactly
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
    private var bgm: AVAudioPlayer?

    private static let voices = 3   // so the same sound can overlap itself

    private init() {
        // ambient means we respect the silent switch and dont cut whatever the player
        // already has going. switch to .playback if we ever want sound on silent.
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

        assert(Bundle.main.url(forResource: "bgm", withExtension: "m4a") != nil, "bgm.m4a is not in the bundle")
        if let url = Bundle.main.url(forResource: "bgm", withExtension: "m4a") {
            bgm = try? AVAudioPlayer(contentsOf: url)
            bgm?.numberOfLoops = -1
            bgm?.prepareToPlay()
        }
    }

    static var sfxVolume: Float   { saved("sfxVolume") }
    static var musicVolume: Float { saved("musicVolume") }

    private static func saved(_ key: String) -> Float {
        Float(UserDefaults.standard.object(forKey: key) as? Double ?? 1)
    }

    /// starts the loop if it isnt running and sets the volume. no argument means use the
    /// saved one, so this doubles as the settings slider's hook.
    func music(volume: Double? = nil) {
        guard let bgm else { return }
        bgm.volume = volume.map(Float.init) ?? Self.musicVolume
        if !bgm.isPlaying { bgm.play() }
    }

    func play(_ sfx: SFX, volume: Float = 1) {
        guard let voices = pool[sfx], !voices.isEmpty, Self.sfxVolume > 0 else { return }
        let i = (next[sfx] ?? 0) % voices.count
        next[sfx] = i + 1
        let p = voices[i]
        p.volume = volume * Self.sfxVolume
        p.currentTime = 0
        p.play()
    }
}
