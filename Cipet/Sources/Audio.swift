import AVFoundation

/// SFX placeholder — file WAV-nya di-generate, tinggal ditimpa sama audio asli nanti.
/// Nama file di Resources/Audio harus sama persis sama case di bawah.
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
    private static let voices = 3            // biar bunyi yang sama bisa numpuk

    private init() {
        // .ambient: ikut tombol silent, nggak motong musik yang lagi diputar pemain
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
