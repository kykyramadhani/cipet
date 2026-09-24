import SwiftUI

@Observable final class LoadingViewModel {
    private(set) var progress = 0.0

    var onFinish: () -> Void = {}

    private var held = 0.0
    private var done = false

    /// where the angkot's left edge sits: on the head of the fill, a bit behind it
    var vanX: CGFloat { Loading.bar.minX + fillWidth - Loading.angkotLead }
    var fillWidth: CGFloat { Loading.bar.width * progress }

    func tick(_ dt: Double) {
        guard !done else { return }
        if progress < 1 {
            progress = min(1, progress + dt / Loading.duration)
            return
        }
        held += dt
        if held >= Loading.hold {
            done = true
            onFinish()
        }
    }
}
