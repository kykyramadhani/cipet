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
    /// the clock in the last ten seconds. a continuous recording rather than a click on
    /// the second, so it loops and fades out instead of being fired per tick.
    private var clock: AVAudioPlayer?
    private var lastPlayed: [SFX: TimeInterval] = [:]

    private static let voices = 3   // so the same sound can overlap itself
    /// a state that flickers cant machine-gun the same sound. one event, one playback.
    private static let minGap: TimeInterval = 0.12

    /// where both sliders start on a fresh install. it lives here rather than in the panel
    /// so the knob and the volume it stands for can never disagree — which is exactly what
    /// they used to do: the panel opened at two thirds while everything played at full.
    static let defaultVolume: Double = 0.667

    private init() {
        UserDefaults.standard.register(defaults: ["sfxVolume":   Self.defaultVolume,
                                                  "musicVolume": Self.defaultVolume])

        // ambient means we respect the silent switch and dont cut whatever the player
        // already has going. switch to .playback if we ever want sound on silent.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        for sfx in SFX.allCases {
            guard let url = Bundle.main.url(forResource: sfx.rawValue, withExtension: "wav") else {
                assertionFailure("\(sfx.rawValue).wav is not in the bundle")
                continue
            }
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

        assert(Bundle.main.url(forResource: Self.clockTrack, withExtension: "wav") != nil,
               "\(Self.clockTrack).wav is not in the bundle")
        if let url = Bundle.main.url(forResource: Self.clockTrack, withExtension: "wav") {
            clock = try? AVAudioPlayer(contentsOf: url)
            clock?.numberOfLoops = -1
            clock?.prepareToPlay()
        }
    }

    private static let clockTrack = "clock_ticking"
    /// sits under the music — it's a nag, not an alarm
    private static let clockLevel: Float = 0.8

    static var sfxVolume: Float   { saved("sfxVolume") }
    static var musicVolume: Float { saved("musicVolume") }

    private static func saved(_ key: String) -> Float {
        Float(UserDefaults.standard.object(forKey: key) as? Double ?? defaultVolume)
    }

    /// starts the loop if it isnt running and sets the volume. no argument means use the
    /// saved one, so this doubles as the settings slider's hook.
    func music(volume: Double? = nil) {
        guard let bgm else { return }
        bgm.volume = volume.map(Float.init) ?? Self.musicVolume
        if !bgm.isPlaying { bgm.play() }
    }

    /// the ticking runs for the last stretch of a round, so it's started and stopped
    /// rather than played. calling it again while it's already going is a no-op, which is
    /// what lets the view drive it straight off the state.
    func ticking(_ on: Bool) {
        guard let clock else { return }
        if on {
            clock.volume = Self.clockLevel * Self.sfxVolume
            guard !clock.isPlaying, Self.sfxVolume > 0 else { return }
            clock.currentTime = 0
            clock.play()
        } else if clock.isPlaying {
            clock.stop()
        }
    }

    func play(_ sfx: SFX, volume: Float? = nil) {
        play(sfx, volume: volume, at: Self.sfxVolume)
    }

    /// dragging the sfx slider ticks at the level the knob is on right now, so you hear
    /// what you're setting instead of guessing. the drag changes every frame and the gap
    /// above thins that down to a ratchet rather than a buzz.
    func preview(_ sfx: SFX, at level: Double) {
        play(sfx, volume: nil, at: Float(level))
    }

    private func play(_ sfx: SFX, volume: Float?, at master: Float) {
        let volume = volume ?? sfx.level
        guard let voices = pool[sfx], !voices.isEmpty, master > 0 else { return }

        let now = Date.timeIntervalSinceReferenceDate
        guard now - (lastPlayed[sfx] ?? -.greatestFiniteMagnitude) >= Self.minGap else { return }
        lastPlayed[sfx] = now
        let i = (next[sfx] ?? 0) % voices.count
        next[sfx] = i + 1
        let p = voices[i]
        p.volume = volume * master
        p.currentTime = 0
        p.play()
    }
}

func runAudioChecks() {
    #if DEBUG
    // the knob and the volume have to be reading the same number, whether or not anybody
    // has ever touched the slider
    let fresh = UserDefaults.standard.object(forKey: "sfxVolume") as? Double
    assert(fresh != nil, "the defaults have to be registered before anything asks")
    assert(abs(Double(Audio.sfxVolume) - (fresh ?? 0)) < 0.0001)
    assert(abs(Double(Audio.musicVolume)
               - (UserDefaults.standard.object(forKey: "musicVolume") as? Double ?? 0)) < 0.0001)
    #endif
}
