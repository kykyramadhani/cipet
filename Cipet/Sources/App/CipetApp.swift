import SwiftUI

@main
struct CipetApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

// loading, menu, tutorial, countdown, round. restarting a round stays in the round,
// it doesnt come back through the intro.
struct RootView: View {
    @State private var router = AppRouter()

    var body: some View {
        ZStack {
            switch router.screen {
            case .loading:   LoadingView   { router.go(.menu) }.transition(.opacity)
            case .menu:      MainMenuView  { router.go(.tutorial) }.transition(.opacity)
            case .tutorial:  TutorialView  { router.go(.countdown) }.transition(.opacity)
            case .countdown: CountdownView { router.go(.game) }.transition(.opacity)
            case .game:      GameView().transition(.opacity)
            }
        }
        .task { Audio.shared.music() }   // bgm runs across every screen
    }
}
