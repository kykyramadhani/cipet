import SwiftUI

// what the angkot scene draws. the old in-game tutorial's steps are gone, these flags stayed.
struct TutorialStep {
    /// what each scene turns on
    struct Show: OptionSet {
        let rawValue: Int
        static let seatGhosts = Show(rawValue: 1 << 1)   // the faded "sit here" markers
        static let onBoard    = Show(rawValue: 1 << 2)   // thief sat in the angkot
        static let kid        = Show(rawValue: 1 << 3)
    }
}
