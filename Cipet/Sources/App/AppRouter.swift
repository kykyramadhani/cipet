import SwiftUI

// one place that knows what screen we're on. the tutorial is its own screen now, between
// Play and round 1, and only startGame can route to it.
@Observable final class AppRouter {
    enum Screen {
        case loading, menu, tutorial, countdown, pickVictim
        case endGame(Ending)
        /// who, where he sits, and what was left on the clock when Confirm was pressed
        case steal(Seating.Person, CGRect, Double)
    }

    private(set) var screen: Screen = .loading
    let session = GameSession()

    /// the menu starts a fresh game, with the tutorial first if it's owed. Next Round goes
    /// straight back to the countdown and never passes through here.
    func startGame() {
        session.startFirstRound()
        go(session.tutorialPending ? .tutorial : .countdown)
    }

    func tutorialDone() {
        session.tutorialFinished()
        go(.countdown)
    }

    func nextRound(after r: RoundResult) {
        session.nextRound(after: r)
        go(.countdown)
    }

    func endGame(after r: RoundResult, _ how: Ending) {
        session.endGame(after: r)
        go(.endGame(how))
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

    // Play goes to the tutorial first when it's owed, and it hands over to round 1's countdown
    r.startGame()
    if r.session.tutorialPending {
        if case .tutorial = r.screen {} else { assertionFailure("Play has to open the tutorial") }
        r.tutorialDone()
    }
    if case .countdown = r.screen {} else { assertionFailure("then round 1's countdown") }
    assert(!r.session.tutorialPending && r.session.round == 1)

    // nothing in a round can bring it back
    r.go(.pickVictim)
    r.go(.steal(.farLeft, Arrangement.fixed.seats(beside: .farLeft)[0], Steal.round))
    assert(!r.session.tutorialPending)

    // Next Round goes through the countdown again, on a new number, tutorial still gone
    let seating = r.session.arrangement
    r.nextRound(after: RoundResult(value: 20, time: 40))
    assert(r.session.round == 2)
    assert(!r.session.tutorialPending)
    assert(r.session.arrangement != seating)
    if case .countdown = r.screen {} else { assertionFailure("Next Round has to replay the countdown") }

    // ending it goes to the tally instead, keeping what the last round was worth
    r.endGame(after: RoundResult(value: 20, time: 20), .jailed)
    assert(r.session.takings == 40 && r.session.round == 2)
    if case .endGame(.jailed) = r.screen {} else { assertionFailure("End Game has its own screen, per ending") }
    #endif
}
