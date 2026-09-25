import SwiftUI

// one place that knows what screen we're on. the tutorial is not a screen — it's a flag on
// the session, latched so nothing downstream can bring it back.
@Observable final class AppRouter {
    enum Screen {
        case loading, menu, countdown, pickVictim, endGame
        /// who, where he sits, and what was left on the clock when Confirm was pressed
        case steal(Seating.Person, CGRect, Double)
    }

    private(set) var screen: Screen = .loading
    let session = GameSession()

    /// the menu starts a fresh game; Next Round re-enters the countdown without resetting it
    func startGame() {
        session.startFirstRound()
        go(.countdown)
    }

    func nextRound(after r: RoundResult) {
        session.nextRound(after: r)
        go(.countdown)
    }

    func endGame(after r: RoundResult) {
        session.endGame(after: r)
        go(.endGame)
    }

    func go(_ next: Screen) {
        withAnimation(.easeInOut(duration: 0.35)) { screen = next }
    }
}

func runRouterChecks() {
    #if DEBUG
    // same as the session's checks: these bank rounds, and banking moves the record
    let keptRound = Record.shared.highestRound, keptValue = Record.shared.topValue
    defer { Record.shared.restore(round: keptRound, value: keptValue) }

    let r = AppRouter()
    assert(!r.session.tutorialPending, "nothing is armed before a game starts")

    r.startGame()
    let armed = r.session.tutorialPending
    r.go(.pickVictim)
    assert(r.session.tutorialPending == armed, "moving between screens doesnt change it")

    r.session.tutorialFinished()
    r.go(.steal(.farLeft, Seating.seats(beside: .farLeft)[0], Steal.round))
    r.go(.pickVictim)
    assert(!r.session.tutorialPending, "coming back to the pick stage must not re-arm it")

    // Next Round goes through the countdown again, on a new number, tutorial still gone
    let seating = r.session.arrangement
    r.nextRound(after: RoundResult(value: 20, time: 40))
    assert(r.session.round == 2)
    assert(!r.session.tutorialPending)
    assert(r.session.arrangement != seating)
    if case .countdown = r.screen {} else { assertionFailure("Next Round has to replay the countdown") }

    // ending it goes to the tally instead, keeping what the last round was worth
    r.endGame(after: RoundResult(value: 20, time: 20))
    assert(r.session.takings == 40 && r.session.round == 2)
    if case .endGame = r.screen {} else { assertionFailure("End Game has its own screen") }
    #endif
}
