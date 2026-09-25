import SwiftUI

@Observable final class SettingsViewModel {
    var sfx: Double {
        didSet {
            UserDefaults.standard.set(sfx, forKey: "sfxVolume")
            // you cant set a volume you cant hear. every step of the drag plays a tick at
            // exactly the level the knob is on, so the slider and the sound agree.
            if sfx != oldValue { Audio.shared.preview(.click, at: sfx) }
        }
    }

    var music: Double {
        didSet {
            UserDefaults.standard.set(music, forKey: "musicVolume")
            Audio.shared.music(volume: music)
        }
    }

    /// the panel's own view of the language, so tapping a flag redraws the whole game
    var lang: Lang {
        get { L10n.shared.lang }
        set { L10n.shared.lang = newValue }
    }

    init() {
        sfx   = UserDefaults.standard.object(forKey: "sfxVolume")   as? Double ?? Audio.defaultVolume
        music = UserDefaults.standard.object(forKey: "musicVolume") as? Double ?? Audio.defaultVolume
    }
}
