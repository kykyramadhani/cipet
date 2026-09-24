import AVFoundation

/// filenames in Resources/Audio have to match these exactly
enum SFX: String, CaseIterable {
    case success = "sfx_success"
    case caught  = "sfx_caught"
    case move    = "sfx_move"
    case win     = "sfx_win"

    case click     = "button_clicked"       // anything you tap
    case engine    = "vehicle_turnOn"       // the angkot pulling up on the countdown
    case whistle   = "whistle"              // steal time, go
    case seated    = "character_seated"     // he takes the seat he picked
    case grab      = "grabbing_character"   // hand goes in
    case suspicion = "suspicion_bar"        // a strike lands on the suspicion bar
    case warning   = "alert_warning"        // the almost-caught cooldown
    case fight     = "fight"                // caught for real
    case failed    = "failed_stealing"      // jailed
    case stole     = "succeed_stealing"     // the lift came off
    case coins     = "item_increase"        // takings on the succeed card
    case leave     = "out_angkot"           // off to the next angkot
    case postGame  = "post_game"            // the end screen

    /// the long ones need pulling back so they dont sit on top of the music
    var level: Float {
        switch self {
        case .engine:  return 0.45
        case .fight:   return 0.6
        case .warning: return 0.65
        case .postGame, .leave: return 0.7
        default:       return 1
        }
    }
}

final class Audio {
    static let shared = Audio()

    private var pool: [SFX: [AVAudioPlayer]] = [:]
    private var next: [SFX: Int] = [:]
    private var bgm: AVAudioPlayer?
    /// music was asked for before the track finished loading, so start it when it lands
    private var wantsMusic = false
    private var lastPlayed: [SFX: TimeInterval] = [:]

    private static let voices = 3   // so the same sound can overlap itself
    /// a state that flickers cant machine-gun the same sound. one event, one playback.
    private static let minGap: TimeInterval = 0.12

    private init() {
        // ambient means we respect the silent switch and dont cut whatever the player
        // already has going. switch to .playback if we ever want sound on silent.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])

        // activating the session is a round trip to the audio daemon that blocks until it
        // answers, and so does every player's prepareToPlay (51 of them for the sfx), so all
        // of it happens off the main thread and the players are handed back when ready.
        // ponytail: ios 27's activate(options:completionHandler:) does this job, switch to it
        // once the deployment target reaches 27
        DispatchQueue.global(qos: .userInitiated).async {
            try? AVAudioSession.sharedInstance().setActive(true)
            let sounds = Self.sfxPool()
            let track = Self.track("bgm")
            DispatchQueue.main.async {
                self.pool = sounds
                self.bgm = track
                if self.wantsMusic { self.music() }
            }
        }
    }

    private static func sfxPool() -> [SFX: [AVAudioPlayer]] {
        var pool: [SFX: [AVAudioPlayer]] = [:]
        for sfx in SFX.allCases {
            guard let url = Bundle.main.url(forResource: sfx.rawValue, withExtension: "wav") else {
                assertionFailure("\(sfx.rawValue).wav is not in the bundle")
                continue
            }
            pool[sfx] = (0..<voices).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
        }
        return pool
    }

    /// the bgm by name, whichever format it was dropped in as. there has to be exactly one,
    /// or which one plays is anyone's guess.
    private static func track(_ name: String) -> AVAudioPlayer? {
        let found = ["wav", "m4a", "mp3", "caf", "aac"]
            .compactMap { Bundle.main.url(forResource: name, withExtension: $0) }
        assert(found.count == 1, "want one \(name) file in the bundle, found \(found.map(\.lastPathComponent))")
        guard let url = found.first, let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.numberOfLoops = -1
        p.prepareToPlay()
        return p
    }

    static var sfxVolume: Float   { saved("sfxVolume") }
    static var musicVolume: Float { saved("musicVolume") }

    /// what both sliders sit at before anyone touches them
    static let defaultVolume = 0.667

    private static func saved(_ key: String) -> Float {
        Float(UserDefaults.standard.object(forKey: key) as? Double ?? defaultVolume)
    }

    /// starts the loop if it isnt running and sets the volume. no argument means use the
    /// saved one, so this doubles as the settings slider's hook.
    func music(volume: Double? = nil) {
        wantsMusic = true
        guard let bgm else { return }   // still loading, it starts itself when it lands
        bgm.volume = volume.map(Float.init) ?? Self.musicVolume
        if !bgm.isPlaying { bgm.play() }
    }

    func play(_ sfx: SFX, volume: Float? = nil) {
        let volume = volume ?? sfx.level
        guard let voices = pool[sfx], !voices.isEmpty, Self.sfxVolume > 0 else { return }

        let now = Date.timeIntervalSinceReferenceDate
        guard now - (lastPlayed[sfx] ?? -.greatestFiniteMagnitude) >= Self.minGap else { return }
        lastPlayed[sfx] = now
        let i = (next[sfx] ?? 0) % voices.count
        next[sfx] = i + 1
        let p = voices[i]
        p.volume = volume * Self.sfxVolume
        p.currentTime = 0
        p.play()
    }
}
