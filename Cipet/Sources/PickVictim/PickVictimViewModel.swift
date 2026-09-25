import SwiftUI

@Observable final class PickVictimViewModel {
    enum Stage { case victim, seat, ready }

    private(set) var stage: Stage = .victim
    private(set) var victim: Seating.Person?
    private(set) var seat: CGRect?

    /// the round's clock starts the moment the countdown hands over, so choosing a mark
    /// and a seat is played on the same minute as the robbery. whatever is left when
    /// Confirm is pressed is what the steal screen carries on from.
    private(set) var timeLeft = Steal.round

    /// set by the router, which is the only thing that arms it
    var tutorialUp = false
    private(set) var paused = false

    var prompt: String {
        t(stage == .victim ? "Pick your\ntarget\nfirst" : "Now, pick\nthe seat!")
    }
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
        // the kid and the driver are on screen but off limits, whatever gets tapped
        guard !tutorialUp, stage == .victim, Seating.victims.contains(v) else { return }
        victim = v
        stage = .seat
        Audio.shared.play(.click)
    }

    func take(seat spot: CGRect) {
        guard !tutorialUp, stage == .seat, seatsOnOffer.contains(spot) else { return }
        seat = spot
        stage = .ready
        Audio.shared.play(.seated)
    }

    var clock: String { mmss(timeLeft.rounded(.up)) }
    var lowOnTime: Bool { timeLeft <= Steal.warn }
    /// the clock is only running when the screen is really yours: not behind the tutorial
    /// and not behind the pause card
    var running: Bool { !tutorialUp && !paused && timeLeft > 0 }

    func tick(_ dt: Double) {
        guard running else { return }
        timeLeft = max(0, timeLeft - dt)
    }

    func tutorialFinished() { tutorialUp = false }

    // nothing is on a clock here, so pausing is only about putting the menu up. picking
    // still has to stop, or a tap can land on a seat through the card.
    func pause() { guard !tutorialUp else { return }; paused = true }
    func resume() { paused = false }
}
