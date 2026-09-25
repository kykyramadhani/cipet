import SwiftUI

@Observable final class TutorialViewModel {
    private(set) var index = 0
    private(set) var fill: CGFloat = 0   // steal bar, 0...1
    private(set) var spotted = 0         // suspicion slots lit

    var onFinish: () -> Void = {}

    private var elapsed = 0.0

    var step: TutorialStep { TutorialStep.all[index] }
    var isLast: Bool { index == TutorialStep.all.count - 1 }
    var nextTitle: String { t(isLast ? "Play" : "Next") }

    /// the steal bar fills over and over. on the scene that teaches the suspicion bar, each
    /// full pass lights one more slot, and three means caught, then it starts again.
    func tick(_ dt: Double) {
        elapsed += dt
        if elapsed >= Tut.cycle {
            elapsed -= Tut.cycle
            if step.countsSuspicion { spotted = (spotted + 1) % (Tut.slots + 1) }
        }
        fill = CGFloat(elapsed / Tut.cycle)
    }

    func next() {
        guard !isLast else { onFinish(); return }
        index += 1
        reset()
    }

    func skip() { onFinish() }

    private func reset() {
        elapsed = 0
        fill = 0
        spotted = 0
    }
}
