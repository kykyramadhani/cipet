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
                CountdownView(round: router.session.round) { router.go(.pickVictim) }
                    .transition(.opacity)
            case .pickVictim:
                PickVictimView(cast: router.session.arrangement,
                               showTutorial: router.session.tutorialPending,
                               onTutorialDone: router.session.tutorialFinished) { who, seat in
                    router.go(.steal(who, seat))
                }
                .transition(.opacity)
            case let .steal(who, seat):
                StealView(victim: who, thiefSeat: seat, cast: router.session.arrangement) { exit in
                    switch exit {
                    case .nextRound: router.nextRound(banking: Steal.itemValue)
                    case .home:      router.go(.menu)
                    }
                }
                .transition(.opacity)
            }
        }
        .task { Audio.shared.music(); runRouterChecks(); runSessionChecks() }   // bgm runs across every screen
    }
}
