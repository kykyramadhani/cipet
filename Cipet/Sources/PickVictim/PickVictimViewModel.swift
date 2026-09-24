import SwiftUI

@Observable final class PickVictimViewModel {
    enum Stage { case victim, seat, ready }

    private(set) var stage: Stage = .victim
    private(set) var victim: Seating.Person?
    private(set) var seat: CGRect?

    /// the tutorial cuts in over this screen before anything can be picked
    var tutorialUp = Seen.shouldShowTutorial

    var prompt: String { stage == .victim ? "Pick your\nvictim\nfirst" : "Now, pick\nthe seat!" }
    var canConfirm: Bool { stage == .ready }

    /// he stands outside only until a victim is picked. after that he's the ghost inside
    /// the angkot showing where he'd sit, so he cant also be on the kerb.
    var onPavement: Bool { stage == .victim }

    /// how many empty seats get offered depends on where the victim is sitting
    var seatsOnOffer: [CGRect] {
        guard let victim, stage == .seat else { return [] }
        return Seating.seats(beside: victim)
    }

    func pick(_ v: Seating.Person) {
        guard !tutorialUp, stage == .victim else { return }
        victim = v
        stage = .seat
    }

    func take(seat spot: CGRect) {
        guard !tutorialUp, stage == .seat, seatsOnOffer.contains(spot) else { return }
        seat = spot
        stage = .ready
    }

    func tutorialFinished() {
        tutorialUp = false
        Seen.tutorial = true
    }
}
