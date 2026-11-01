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

    /// the menu starts a fresh game, with the tutorial first on the very first Play only —
    /// whether it's been done lives in the view's @AppStorage. Next Round goes straight back
    /// to the countdown and never passes through here.
    func startGame(tutorial: Bool) {
        session.startFirstRound()
        go(tutorial ? .tutorial : .countdown)
    }

    func tutorialDone() { go(.countdown) }

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

    // the first Play goes to the tutorial, and it hands over to round 1's countdown
    r.startGame(tutorial: true)
    if case .tutorial = r.screen {} else { assertionFailure("the first Play has to open the tutorial") }
    r.tutorialDone()
    if case .countdown = r.screen {} else { assertionFailure("then round 1's countdown") }
    assert(r.session.round == 1)

    // once it's been done, Play goes straight to round 1
    r.startGame(tutorial: false)
    if case .countdown = r.screen {} else { assertionFailure("no tutorial after it's been done") }

    // nothing in a round can bring it back
    r.go(.pickVictim)
    r.go(.steal(.farLeft, Arrangement.fixed.seats(beside: .farLeft)[0], Steal.round))

    // Next Round goes through the countdown again, on a new number, tutorial still gone
    let seating = r.session.arrangement
    r.nextRound(after: RoundResult(value: 20, time: 40))
    assert(r.session.round == 2)
    assert(r.session.arrangement != seating)
    if case .countdown = r.screen {} else { assertionFailure("Next Round has to replay the countdown") }

    // ending it goes to the tally instead, keeping what the last round was worth
    r.endGame(after: RoundResult(value: 20, time: 20), .jailed)
    assert(r.session.takings == 40 && r.session.round == 2)
    if case .endGame(.jailed) = r.screen {} else { assertionFailure("End Game has its own screen, per ending") }
    #endif
}
