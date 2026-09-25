import SwiftUI

// the whole beat sheet runs off one clock rather than a chain of sleeps, so the pause
// button can hold it where it is instead of the count carrying on behind the card.
@Observable final class CountdownViewModel {
    var round = 1
    /// nil while the round card is up, 0...4 once we're counting
    private(set) var step: Int?
    private(set) var paused = false

    var onStart: () -> Void = {}

    private var elapsed = 0.0
    private var revved = false   // the engine only turns over once
    private var done = false
    /// the checks below run the whole beat sheet, and they must not make a sound doing it
    private let audible: Bool

    init(audible: Bool = true) { self.audible = audible }

    var waiting: Bool { step == nil }
    var stealing: Bool { step == Countdown.steal }
    var label: String { step.map { t(Countdown.labels[$0]) } ?? "\(t("Round")) #\(round)" }
    var labelSize: CGFloat { waiting ? Countdown.roundSize : Countdown.countSize }
    var vanX: CGFloat { step.map(Countdown.vanX) ?? Countdown.readyX }

    func tick(_ dt: Double) {
        guard !paused, !done else { return }
        elapsed += dt

        // the round card sits there on its own for a beat, then the count starts itself
        let since = elapsed - Countdown.cardHold
        guard since >= 0 else { return }

        if !revved {
            revved = true
            if audible { Audio.shared.play(.engine) }
        }

        let beat = min(Countdown.labels.count - 1, Int(since / Countdown.tick))
        if beat != step {
            step = beat
            if beat == Countdown.steal, audible { Audio.shared.play(.whistle) }
        }

        if since >= Countdown.total {
            done = true
            onStart()
        }
    }

    func pause() {
        guard !done else { return }
        paused = true
    }

    func resume() { paused = false }
}

func runCountdownModelChecks() {
    #if DEBUG
    // it starts itself: nothing is tapped, the card holds, then 3-2-1-Start-Steal Time
    var started = false
    let vm = CountdownViewModel(audible: false)
    vm.onStart = { started = true }
    assert(vm.waiting, "the round card comes up first")

    // a frame short of the hold and a few frames past it, so the check isnt riding on
    // where sixty additions of a sixtieth land
    for _ in 0..<Int(Countdown.cardHold * 60) - 1 { vm.tick(1.0 / 60) }
    assert(vm.waiting, "and it stays up for the whole hold")
    for _ in 0..<3 { vm.tick(1.0 / 60) }
    assert(vm.step == 0, "then the count starts on its own, with nothing to tap")

    // pausing freezes the beat it was on, and picks it up again from there
    vm.pause()
    let held = vm.step
    for _ in 0..<240 { vm.tick(1.0 / 60) }
    assert(vm.step == held && !started, "a paused countdown does not run on behind the card")
    vm.resume()

    var frames = 0
    while !started && frames < 60 * 60 { vm.tick(1.0 / 60); frames += 1 }
    assert(started, "it has to reach the round eventually")
    assert(vm.step == Countdown.steal, "and finish on Steal Time")

    // and once it has handed over, it stops dead
    let after = vm.step
    for _ in 0..<60 { vm.tick(1.0 / 60) }
    assert(vm.step == after, "nothing moves after the round has begun")
    #endif
}
