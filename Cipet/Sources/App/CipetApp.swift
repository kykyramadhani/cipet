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
                CountdownView(round: router.session.round,
                              onStart: { router.go(.pickVictim) },
                              onHome: { router.go(.menu) })
                    .transition(.opacity)
            case .pickVictim:
                PickVictimView(cast: router.session.arrangement, items: router.session.items,
                               onHome: { router.go(.menu) }) { who, seat, left in
                    router.go(.steal(who, seat, left))
                }
                .transition(.opacity)
            case let .steal(who, seat, left):
                StealView(victim: who, thiefSeat: seat, timeLeft: left,
                          cast: router.session.arrangement, round: router.session.round,
                          items: router.session.items) { exit in
                    switch exit {
                    case let .nextRound(r): router.nextRound(after: r)
                    case let .endGame(r, how): router.endGame(after: r, how)
                    case .home:             router.go(.menu)
                    }
                }
                .transition(.opacity)
            case let .endGame(how):
                EndGameView(session: router.session, ending: how) { router.go(.menu) }
                    .transition(.opacity)
            }
        }
        .task {
            Audio.shared.music()
            runRouterChecks(); runSessionChecks(); runEndChecks(); runRiderChecks()
            runLocaleChecks(); runAudioChecks()
        }
    }
}
