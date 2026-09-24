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
            case .menu:       MainMenuView   { router.startRun() }.transition(.opacity)
            case .countdown:  CountdownView  { router.go(.pickVictim) }.transition(.opacity)
            case .pickVictim:
                PickVictimView(showTutorial: router.tutorialPending,
                               onTutorialDone: router.tutorialFinished) { who, seat in
                    router.go(.steal(who, seat))
                }
                .transition(.opacity)
            case let .steal(who, seat):
                StealView(victim: who, thiefSeat: seat) { exit in
                    // a new round goes back to the pick stage, and the tutorial stays gone
                    switch exit {
                    case .nextRound: router.go(.pickVictim)
                    case .home:      router.go(.menu)
                    }
                }
                .transition(.opacity)
            }
        }
        .task { Audio.shared.music(); runRouterChecks() }   // bgm runs across every screen
    }
}
