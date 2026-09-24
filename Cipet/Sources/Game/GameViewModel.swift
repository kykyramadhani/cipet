import SwiftUI

// owns the round and is the only place that fires sfx, so the Game struct itself stays
// pure and testable.
@Observable final class GameViewModel {
    var game: Game

    private var lastTaken: Int
    private var lastThief: Int
    private var lastPhase: Phase

    init() {
        let start = Game.new()
        game = start
        lastTaken = start.taken
        lastThief = start.thief
        lastPhase = start.phase
    }

    func tick(_ dt: Double) {
        game.tick(dt)
        reactToChanges()
    }

    func restart() {
        game.restart()
        sync()
    }

    /// taps mutate the game straight through the binding, so we diff after every frame
    /// instead of hooking each action
    private func reactToChanges() {
        if game.taken != lastTaken {
            if game.taken > lastTaken { Audio.shared.play(.success) }
            lastTaken = game.taken
        }
        if game.thief != lastThief {
            lastThief = game.thief
            Audio.shared.play(.move, volume: 0.55)
        }
        if game.phase != lastPhase {
            lastPhase = game.phase
            if game.phase == .caught { Audio.shared.play(.caught) }
            if game.phase == .win    { Audio.shared.play(.win) }
        }
    }

    private func sync() {
        lastTaken = game.taken
        lastThief = game.thief
        lastPhase = game.phase
    }
}
