import SwiftUI

// the best a player has ever managed, kept between launches. it's the only thing in the
// game that outlives a run, which is what the Record button on the menu is for — and why
// that button isn't there at all until there's something to show.
@Observable final class Record {
    static let shared = Record()

    private static let roundKey = "recordRound"
    // whole rupiah now. the old key held thousands, so it's left behind rather than misread
    private static let valueKey = "recordValueRupiah"

    /// the furthest round anyone has reached, counting the one they were caught on
    private(set) var highestRound: Int
    /// the biggest a single run's takings have got, in whole rupiah
    private(set) var topValue: Int

    private init() {
        highestRound = UserDefaults.standard.integer(forKey: Self.roundKey)
        topValue = UserDefaults.standard.integer(forKey: Self.valueKey)
    }

    /// nothing to show until a round has actually been finished, won or lost
    var hasAny: Bool { highestRound > 0 }

    var roundText: String { "\(highestRound)" }
    var valueText: String { rupiah(topValue) }

    /// called as each round is banked, so a run that's abandoned halfway still counts
    /// whatever it got to
    func note(round: Int, takings: Int) {
        if round > highestRound {
            highestRound = round
            UserDefaults.standard.set(round, forKey: Self.roundKey)
        }
        if takings > topValue {
            topValue = takings
            UserDefaults.standard.set(takings, forKey: Self.valueKey)
        }
    }

    #if DEBUG
    /// the checks below need somewhere to write that isn't the player's own record
    func restore(round: Int, value: Int) {
        highestRound = round
        topValue = value
        UserDefaults.standard.set(round, forKey: Self.roundKey)
        UserDefaults.standard.set(value, forKey: Self.valueKey)
    }
    #endif
}

func runRecordChecks() {
    #if DEBUG
    let r = Record.shared
    let wasRound = r.highestRound, wasValue = r.topValue

    r.restore(round: 0, value: 0)
    assert(!r.hasAny, "a fresh install has no record, so no button")

    r.note(round: 1, takings: 0)
    assert(r.hasAny, "one finished round is enough to have one")
    assert(r.roundText == "1" && r.valueText == rupiah(0))

    // it only ever goes up, whichever way a run ends
    r.note(round: 4, takings: 60)
    r.note(round: 2, takings: 20)
    assert(r.highestRound == 4 && r.topValue == 60, "a worse run cant undo a better one")

    // the two move independently — a long run and a rich one need not be the same run
    r.note(round: 9, takings: 0)
    r.note(round: 1, takings: 1_500_000)
    assert(r.highestRound == 9 && r.topValue == 1_500_000)
    assert(r.valueText == rupiah(1_500_000))

    // and it survives a relaunch, which is the whole point of it
    assert(UserDefaults.standard.integer(forKey: "recordRound") == 9)
    assert(UserDefaults.standard.integer(forKey: "recordValueRupiah") == 1_500_000)

    r.restore(round: wasRound, value: wasValue)
    #endif
}
