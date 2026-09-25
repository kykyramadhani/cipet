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
        "Now, pick the seat!":      "Sekarang, pilih kursinya!",
        "Confirm if you\u{2019}re ready!": "Konfirmasi kalau sudah siap!",
        "Confirm":                  "Konfirmasi",

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
        "Hold anywhere to fill the bar": "Tahan di mana saja untuk isi bar",
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
        "Failed":           "Gagal",
        "Try again next time": "Coba lagi lain kali",
        "Congrats?":        "Selamat?",
        "Avg time":         "Rata-rata",
        "Total Items":      "Total Barang",
        "Total Rounds":     "Total Ronde",
        "Back to Home":     "Kembali",
    ]
}

/// money is whole rupiah underneath. under a million it's thousands, "Rp 999k" in both
/// languages; from a million up it's "Rp 1.5M" in english and "Rp 1,5 JT" in indonesian
func rupiah(_ amount: Int) -> String {
    let ind = L10n.shared.lang == .ind
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 2
    f.locale = Locale(identifier: ind ? "id_ID" : "en_US")
    let millions = amount >= 1_000_000
    let n = f.string(from: NSNumber(value: Double(amount) / (millions ? 1_000_000 : 1_000))) ?? "0"
    guard millions else { return "Rp \(n)k" }
    return ind ? "Rp \(n) JT" : "Rp \(n)M"
}

func runLocaleChecks() {
    #if DEBUG
    let was = L10n.shared.lang

    L10n.shared.lang = .eng
    assert(t("Play") == "Play", "english has to come back untouched")
    assert(rupiah(1_500_000) == "Rp 1.5M" && rupiah(1_000_000) == "Rp 1M" && rupiah(3_250_000) == "Rp 3.25M")
    assert(rupiah(999_000) == "Rp 999k" && rupiah(20_000) == "Rp 20k" && rupiah(5_000) == "Rp 5k")
    L10n.shared.lang = .ind
    assert(t("Play") == "Main", "indonesian has to actually swap the word")
    assert(rupiah(1_500_000) == "Rp 1,5 JT" && rupiah(1_000_000) == "Rp 1 JT" && rupiah(250_000) == "Rp 250k")
    assert(t("Rp 20k") == "Rp 20k", "anything with no entry falls through as it is")

    for (english, indonesian) in Indonesian.table {
        assert(!english.isEmpty && !indonesian.isEmpty, "no blank entries")
        assert(english != indonesian, "\(english) is not a translation of itself")
    }
    // the signs scale themselves to their art now, so what's left to check is that no
    // translation is so long the fit shrinks it past legible. measured, not counted:
    // TERCIDUK is only 8 characters and still overran the plate at full size.
    assert(Jail.signScale(t("JAILED")) >= 0.7, "the jail word shrinks too far to read")
    assert(Jail.signScale(t("Failed")) >= 0.7)
    assert(Countdown.stealScale([t("STEAL"), t("TIME")]) >= 0.7,
           "the steal sign shrinks too far to read")

    L10n.shared.lang = was
    #endif
}
