import SwiftUI

@Observable final class PickVictimViewModel {
    /// the two passengers the art gives us a lit version of
    enum Victim { case farBench, nearBench }

    enum Stage { case victim, seat, ready }

    private(set) var stage: Stage = .victim
    private(set) var victim: Victim?
    private(set) var seat: Int?              // which of the two near-bench spots he took

    /// the tutorial cuts in over this screen before anything can be picked
    var tutorialUp = Seen.shouldShowTutorial

    var prompt: String { stage == .victim ? "Pick your\nvictim\nfirst" : "Now, pick\nthe seat!" }
    var canConfirm: Bool { stage == .ready }

    /// he's only out on the pavement until he's picked somewhere to sit
    var onPavement: Bool { stage != .ready }

    func pick(_ v: Victim) {
        guard !tutorialUp, stage == .victim else { return }
        victim = v
        stage = .seat
    }

    /// the far bench only has the one spot beside the victim, the near bench has two
    func take(seat i: Int?) {
        guard !tutorialUp, stage == .seat else { return }
        seat = i
        stage = .ready
    }

    func tutorialFinished() {
        tutorialUp = false
        Seen.tutorial = true
    }
}
