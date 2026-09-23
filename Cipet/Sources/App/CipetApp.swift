import SwiftUI

@main
struct CipetApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

// loading -> menu -> countdown -> pick a victim -> round. the tutorial isnt a screen of its
// own, it interrupts the pick stage, so it lives inside PickVictimView.
struct RootView: View {
    @State private var router = AppRouter()

    var body: some View {
        ZStack {
            switch router.screen {
            case .loading:    LoadingView    { router.go(.menu) }.transition(.opacity)
            case .menu:       MainMenuView   { router.go(.countdown) }.transition(.opacity)
            case .countdown:  CountdownView  { router.go(.pickVictim) }.transition(.opacity)
            case .pickVictim: PickVictimView { router.go(.game) }.transition(.opacity)
            case .game:       GameView().transition(.opacity)
            }
        }
        .task { Audio.shared.music() }   // bgm runs across every screen
    }
}
