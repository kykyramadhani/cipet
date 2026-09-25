import SwiftUI

@main
struct CipetApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

// loading -> menu -> countdown -> pick a victim -> steal. the tutorial isnt a screen of its
// own, it interrupts the pick stage, so it lives inside PickVictimView.
struct RootView: View {
    @State private var router = AppRouter()

    var body: some View {
        ZStack {
            switch router.screen {
            case .loading:    LoadingView    { router.go(.menu) }.transition(.opacity)
            case .menu:       MainMenuView   { router.startGame() }.transition(.opacity)
            case .countdown:
                CountdownView(round: router.session.round,
                              onStart: { router.go(.pickVictim) },
                              onHome: { router.go(.menu) })
                    .transition(.opacity)
            case .pickVictim:
                PickVictimView(cast: router.session.arrangement,
                               showTutorial: router.session.tutorialPending,
                               onTutorialDone: router.session.tutorialFinished,
                               onHome: { router.go(.menu) }) { who, seat, left in
                    router.go(.steal(who, seat, left))
                }
                .transition(.opacity)
            case let .steal(who, seat, left):
                StealView(victim: who, thiefSeat: seat, timeLeft: left,
                          cast: router.session.arrangement) { exit in
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
        .task {
            Audio.shared.music()
            runRouterChecks(); runSessionChecks(); runEndChecks(); runRiderChecks()
            runLocaleChecks(); runAudioChecks()
        }
    }
}
