import Foundation

enum Flags {
    /// off while we're still building the tutorial, so it shows every single run.
    /// flip to true and it only interrupts the first game after a fresh install.
    static let tutorialOnlyOnFirstPlay = false
}

enum Seen {
    private static let key = "tutorialSeen"

    static var tutorial: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static var shouldShowTutorial: Bool {
        Flags.tutorialOnlyOnFirstPlay ? !tutorial : true
    }
}
