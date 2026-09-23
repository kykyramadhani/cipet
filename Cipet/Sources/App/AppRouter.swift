import SwiftUI

@Observable final class AppRouter {
    enum Screen { case loading, menu, tutorial, countdown, game }

    private(set) var screen: Screen = .loading

    func go(_ next: Screen) {
        withAnimation(.easeInOut(duration: 0.35)) { screen = next }
    }
}
