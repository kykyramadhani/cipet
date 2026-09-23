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
        sfx   = UserDefaults.standard.object(forKey: "sfxVolume")   as? Double ?? 0.667
        music = UserDefaults.standard.object(forKey: "musicVolume") as? Double ?? 0.667
    }
}
