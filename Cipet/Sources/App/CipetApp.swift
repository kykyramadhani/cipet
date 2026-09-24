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
            case .menu:       MainMenuView   { router.go(.countdown) }.transition(.opacity)
            case .countdown:  CountdownView  { router.go(.pickVictim) }.transition(.opacity)
            case .pickVictim:
                PickVictimView { who, seat in router.go(.steal(who, seat)) }
                    .transition(.opacity)
            case let .steal(who, seat):
                StealView(victim: who, thiefSeat: seat) { _ in router.go(.pickVictim) }
                    .transition(.opacity)
            }
        }
        .task { Audio.shared.music() }   // bgm runs across every screen
    }
}
