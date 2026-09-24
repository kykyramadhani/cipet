import SwiftUI

@Observable final class SettingsViewModel {
    var sfx: Double {
        didSet { UserDefaults.standard.set(sfx, forKey: "sfxVolume") }
    }

    var music: Double {
        didSet {
            UserDefaults.standard.set(music, forKey: "musicVolume")
            Audio.shared.music(volume: music)
        }
    }

    init() {
        sfx   = Double(Audio.sfxVolume)
        music = Double(Audio.musicVolume)
    }
}
