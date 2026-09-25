import SwiftUI

/// the two languages the settings panel offers
enum Lang: String, CaseIterable {
    case eng, ind

    var label: String { self == .eng ? "ENG" : "IND" }
}

// the game is small enough that a table beats a strings file: no bundle juggling, and the
// switch lands on the very next frame because every `t(...)` reads this object from inside
// a swiftui body, so observation redraws whatever was showing.
@Observable final class L10n {
    static let shared = L10n()

    private static let key = "language"

    var lang: Lang {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: Self.key) }
    }

    private init() {
        lang = Lang(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .eng
    }
}

/// english in, whatever we're speaking out. an english string with no entry falls through
/// unchanged, so a missing translation shows the original rather than a key.
func t(_ english: String) -> String {
    guard L10n.shared.lang == .ind else { return english }
    return Indonesian.table[english] ?? english
}

enum Indonesian {
    // keyed by the english the code already reads, so the source stays readable and there
    // is nothing to keep in sync but this one list
    static let table: [String: String] = [
        // menu
        "Ready to Steal?": "Siap Nyopet?",
        "Play":            "Main",
        "Settings":        "Pengaturan",
        "Record":          "Rekor",
        "Highest Round":   "Ronde Tertinggi",
        "Top Value":       "Nilai Tertinggi",
        "Music":           "Musik",
        "Language":        "Bahasa",

        // countdown
        "Round":  "Ronde",
        "Start":  "Mulai",
        "STEAL":  "WAKTUNYA",
        "TIME":   "NYOPET",

        // picking a target
        "Pick your\ntarget\nfirst": "Pilih\ntargetmu\ndulu",
        "Now, pick\nthe seat!":     "Sekarang,\npilih\nkursinya",
        "Confirm":                  "Konfirmasi",

        // the instructions behind the info button. Paused/Resume/Main Menu are already
        // down with the round itself, which is the other place they show.
        "Instruction": "Petunjuk",
        "Beware of other passengers suspicion bar.":
            "Awas, perhatikan bar kecurigaan penumpang lain.",
        "If the suspicion bar is full, your suspicion level will increase":
            "Kalau bar kecurigaan penuh, level kecurigaanmu naik",
        "If the level full you'll get into jail":
            "Kalau levelnya penuh kamu masuk penjara",
        "You'll succeed if the bar is full by keeping passenger awareness safe":
            "Kamu berhasil kalau barnya penuh dan penumpang tetap tenang",
        "Hold anywhere to fill the bar": "Tahan di mana saja buat isi barnya",

        // tutorial
        "Tutorials":    "Tutorial",
        "Skip":         "Lewati",
        "Next":         "Lanjut",
        "This is you!": "Ini kamu!",
        "Choose your target":              "Pilih targetmu",
        "Pick a seat to make your move":   "Pilih kursi buat beraksi",
        "Grab the item and keep your hand steady while stealing.":
            "Ambil barangnya dan tahan tanganmu selama nyopet.",
        "Watch out for other passengers\u{2019} suspicion bar.":
            "Awas, perhatikan bar kecurigaan penumpang lain.",
        "Grab the item before time runs out !":
            "Ambil barangnya sebelum waktu habis !",

        // the round itself
        "Hold to fill the bar":   "Tahan untuk isi bar",
        "Stop for":               "Berhenti",
        "You almost get caught!": "Kamu hampir ketahuan!",
        "Paused":                 "Jeda",
        "Resume":                 "Lanjutkan",
        "Main Menu":              "Menu Utama",

        // endings
        "Succeed!":         "Berhasil!",
        "Remaining time":   "Sisa waktu",
        "Item value":       "Nilai barang",
        "Total Item value": "Total nilai barang",
        "End Game":         "Selesai",
        "Next Round":       "Ronde Baru",
        "JAILED":           "TERCIDUK",
        "Congrats?":        "Selamat?",
        "Avg time":         "Rata-rata",
        "Total Items":      "Total Barang",
        "Total Rounds":     "Total Ronde",
        "Back to Home":     "Kembali",
    ]
}

func runLocaleChecks() {
    #if DEBUG
    let was = L10n.shared.lang

    L10n.shared.lang = .eng
    assert(t("Play") == "Play", "english has to come back untouched")
    L10n.shared.lang = .ind
    assert(t("Play") == "Main", "indonesian has to actually swap the word")
    assert(t("Rp 20k") == "Rp 20k", "anything with no entry falls through as it is")

    for (english, indonesian) in Indonesian.table {
        assert(!english.isEmpty && !indonesian.isEmpty, "no blank entries")
        assert(english != indonesian, "\(english) is not a translation of itself")
    }
    // the signs scale themselves to their art now, so what's left to check is that no
    // translation is so long the fit shrinks it past legible. measured, not counted:
    // TERCIDUK is only 8 characters and still overran the plate at full size.
    assert(Jail.signScale(t("JAILED")) >= 0.7, "the jail word shrinks too far to read")
    assert(Countdown.stealScale([t("STEAL"), t("TIME")]) >= 0.7,
           "the steal sign shrinks too far to read")

    L10n.shared.lang = was
    #endif
}
