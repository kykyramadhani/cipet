import SwiftUI

@Observable final class CountdownViewModel {
    /// nil while the round card is up waiting for its button, 0...3 once we're counting
    private(set) var step: Int?

    var onStart: () -> Void = {}

    var waiting: Bool { step == nil }
    var label: String { step.map { Countdown.labels[$0] } ?? "Round #1" }
    var labelSize: CGFloat { waiting ? Countdown.roundSize : Countdown.countSize }
    var vanX: CGFloat { step.map(Countdown.vanX) ?? Countdown.readyX }

    func begin() {
        guard step == nil else { return }
        step = 0
        Task { @MainActor in
            for i in 1..<Countdown.labels.count {
                try? await Task.sleep(for: .seconds(Countdown.tick))
                step = i
            }
            try? await Task.sleep(for: .seconds(Countdown.hold))
            onStart()
        }
    }
}
