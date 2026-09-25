import SwiftUI

/// the two languages the settings panel offers
enum Lang: String, CaseIterable {
    case eng, ind

    var label: String { self == .eng ? "ENG" : "IND" }
}

// the words live in Resources/Localizable.xcstrings, keyed by the english the code already
// reads. the language is the game's own setting rather than the phone's, so `t(...)` asks
// the catalog's indonesian bundle directly — and because every `t(...)` reads this object
// from inside a swiftui body, flipping it redraws whatever was showing on the next frame.
@Observable final class L10n {
    static let shared = L10n()

    private static let key = "language"

    var lang: Lang {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: Self.key) }
    }

    private init() {
        lang = Lang(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .eng
    }

    /// the catalog's indonesian, as the build compiles it into id.lproj
    static let indonesian = Bundle.main.path(forResource: "id", ofType: "lproj").flatMap(Bundle.init(path:))
}

/// english in, whatever we're speaking out. an english string with no entry falls through
/// unchanged, so a missing translation shows the original rather than a key.
func t(_ english: String) -> String { t(english, in: L10n.shared.lang) }

func t(_ english: String, in lang: Lang) -> String {
    guard lang == .ind, let bundle = L10n.indonesian else { return english }
    return bundle.localizedString(forKey: english, value: english, table: nil)
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

    // every entry in the catalog made it into the build, and none is blank or untranslated
    let built = L10n.indonesian.flatMap { $0.url(forResource: "Localizable", withExtension: "strings") }
        .flatMap { NSDictionary(contentsOf: $0) as? [String: String] } ?? [:]
    assert(built.count == 60, "the catalog should carry all 60 entries, found \(built.count)")
    for (english, indonesian) in built {
        assert(!english.isEmpty && !indonesian.isEmpty, "no blank entries")
        assert(english != indonesian, "\(english) is not a translation of itself")
        assert(t(english) == indonesian, "\(english) doesnt come back as its translation")
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
