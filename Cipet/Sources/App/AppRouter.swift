import SwiftUI

// one place that knows what screen we're on. the tutorial is not a screen — it's a flag that
// belongs to the opening pick of a run, latched here so nothing downstream can bring it back.
@Observable final class AppRouter {
    enum Screen {
        case loading, menu, countdown, pickVictim
        case steal(Seating.Person, CGRect)
    }

    private(set) var screen: Screen = .loading
    private(set) var tutorialPending = false

    /// a run starts at the countdown and is the only thing that can arm the tutorial again
    func startRun() {
        tutorialPending = Seen.shouldShowTutorial
        go(.countdown)
    }

    func tutorialFinished() {
        tutorialPending = false
        Seen.tutorial = true
    }

    func go(_ next: Screen) {
        withAnimation(.easeInOut(duration: 0.35)) { screen = next }
    }
}

func runRouterChecks() {
    #if DEBUG
    let r = AppRouter()
    assert(!r.tutorialPending, "nothing is armed before a run starts")

    r.startRun()
    let armed = r.tutorialPending
    r.go(.pickVictim)
    assert(r.tutorialPending == armed, "moving between screens doesnt change it")

    r.tutorialFinished()
    assert(!r.tutorialPending)

    // the whole point: once it's done, nothing in the round can bring it back
    r.go(.steal(.farLeft, Seating.seats(beside: .farLeft)[0]))
    r.go(.pickVictim)
    assert(!r.tutorialPending, "coming back to the pick stage must not re-arm the tutorial")
    #endif
}
