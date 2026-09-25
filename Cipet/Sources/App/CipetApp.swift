import SwiftUI

@main
struct CipetApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

// loading -> menu -> tutorial (first game only) -> countdown -> pick a target -> steal
struct RootView: View {
    @State private var router = AppRouter()

    var body: some View {
        ZStack {
            switch router.screen {
            case .loading:    LoadingView    { router.go(.menu) }.transition(.opacity)
            case .menu:       MainMenuView   { router.startGame() }.transition(.opacity)
            case .tutorial:   TutorialView   { router.tutorialDone() }.transition(.opacity)
            case .countdown:
                CountdownView(round: router.session.round) { router.go(.pickVictim) }
                    .transition(.opacity)
            case .pickVictim:
                PickVictimView(cast: router.session.arrangement) { who, seat in
                    router.go(.steal(who, seat))
                }
                .transition(.opacity)
            case let .steal(who, seat):
                StealView(victim: who, thiefSeat: seat, cast: router.session.arrangement) { exit in
                    switch exit {
                    case let .nextRound(r): router.nextRound(after: r)
                    case let .endGame(r):   router.endGame(after: r)
                    case .home:             router.go(.menu)
                    }
                }
                .transition(.opacity)
            case .endGame:
                EndGameView(session: router.session) { router.go(.menu) }.transition(.opacity)
            }
        }
        .task { Audio.shared.music(); runRouterChecks(); runSessionChecks(); runEndChecks(); runRiderChecks() }
    }
}
