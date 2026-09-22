# Cipet — Pickpocketing on the Angkot — Gameplay Prototype

The full main loop: **pick a target → hold to rob → progress races their awareness →
you get the item or you get caught → keep going until the round runs out.** Every drawing in the
game comes from `Placeholder/`.

## Running it

```bash
open Cipet.xcodeproj
```
Pick an iPhone simulator → Run. **Landscape**, iOS 17+.
If you change `project.yml`: `xcodegen generate`.

## How to play

| Action | Control |
|---|---|
| Change seat | Tap an empty seat (the one with the dashed white outline) |
| Rob somebody | **Hold** the passenger sitting to your left or right |
| Rob two at once | From a middle seat, **hold both of them with two fingers** |
| Abort | Let go — the progress is lost and their awareness drops back down on its own |
| Pause | Pause button, top right (the clock, the road and every passenger stop with it) |

The **green** bar is your progress, the **red** bar is the victim's awareness. Green fills first and
you get the item. Red fills first and you are caught, which ends the round. A **!** means their
awareness is climbing. A round is 90 seconds; survive to the end and you win.

Passengers get on and off throughout the round: everyone has their own ride length
(`Tune.rideTime`), and when it is up they get off — **robbed or not, it makes no difference**. The
seat they leave sits empty for a moment (`Tune.boardWait`) before somebody new boards. So a single
round keeps handing you fresh victims.

## Seats

**7 seats** can be used, laid out exactly as in `Placeholder/Benchmark.png`:

- **Far bench — 3 seats.** Passengers face the camera, so they use `victim_far`.
- **Near bench — 4 seats.** We see their backs, so they use `victim_near`.

**The thief can move into any empty seat**, near bench included. The passenger count is capped by
`Tune.maxPassengers` (4 of 7), so there are always at least two free seats to move into.

You can only rob somebody **sitting right next to you on the same bench** — you cannot reach across
the aisle (`Layout.adjacent`). Sit between two passengers and you can hold both at once, two fingers.

The folding seat by the door (with the kid on it) and the driver's seat are scenery, not seats.

## Tech stack

| Part | What it uses |
|---|---|
| Language & UI | **Swift 5 + SwiftUI**, iOS 17, landscape |
| Game loop | `Timer.publish(every: 1/60)` + `.onReceive` — not `TimelineView`, not `SKScene` |
| Graphics | `Image`, everything in the asset catalog |
| Audio | **AVFoundation** (`AVAudioPlayer`), WAV files in `Resources/Audio` |
| Project file | **XcodeGen** (`project.yml`) — the `.xcodeproj` can be regenerated at any time |
| Third-party code | **None.** No SPM, no CocoaPods, no engine |

### SpriteKit or SwiftUI?

**Pure SwiftUI. No SpriteKit anywhere.**

All we need is one background that scrolls sideways, around 15 still sprites, a few bars and some
UI. No physics, no collisions, no particles, no camera, no hundreds of nodes. SwiftUI handles that
at 60fps without breaking a sweat, and we get the HUD, the buttons, the win/lose screens and
SwiftUI Previews for free — none of which we would want to rebuild inside an `SKScene`.

When it would be time to move to SpriteKit:
- hundreds of sprites at once, or a real particle emitter (dust, confetti, exhaust smoke)
- a physics/collision engine
- dense frame-by-frame sprite sheet animation (not just swapping an image per state)
- profiling showing SwiftUI cannot hold 60fps

The move would not hurt: `Game` is a plain struct that never imports SwiftUI. Switching to SpriteKit
would mean rewriting only the drawing layer — the rules carry over untouched. That is the main
reason logic and presentation were split from the start.

### How it fits together

```
CipetApp
      |
   GameView  @State var game: Game          <- the single source of truth
      |
      |  60fps Timer -> game.tick(1/60)
      |        tick: scroll the road, round clock, passenger states,
      |              people getting on and off, steal progress vs awareness,
      |              win / caught
      |
      |  @State changes -> SwiftUI re-renders
      +--> RoadLayer    (road tiles, scrolled)
      +--> CabinLayer   (bus body -> scenery -> seats -> people -> seat UI and tap targets)
      +--> HUD          (score, timer, pause, end screens)

  input: SeatInput -> game.move(to:) / beginSteal / endSteal
  audio: GameView .onChange(taken / thief / phase) -> Audio.shared.play(...)
```

It runs one way: **input → model → render**. The model never calls the view and never calls audio —
the view notices the state change and fires the SFX. That is why `Game` is easy to test with no UI
at all (see `runGameChecks()`).

## What lives where

| File | What's in it |
|---|---|
| `Sources/GameConfig.swift` | `Layout` (scene coordinates), `Art` (sprite sizes), `Tune` (all balancing numbers), `Kind` (per-archetype config) |
| `Sources/Game.swift` | Pure model: passengers, state machine, awareness, stealing, win/lose + self-check |
| `Sources/GameView.swift` | Draws the scene: scrolling road, bus, scenery, sprites, tap targets |
| `Sources/HUD.swift` | Timer, score, pause button, pause and end screens |
| `Sources/Audio.swift` | SFX player, 3 voices per sound so they can overlap |

## What a programmer needs to know

**The scene uses the art's coordinates, not screen pixels.**
`Jalan.png` and `Benchmark.png` are both 2622x1206, and `Benchmark.png` is the composition the
whole scene is rebuilt from. Everything is drawn in that space and scaled once to cover the screen,
so a different phone or orientation keeps the layout correct. Every sprite is placed at its native
size at the coordinates it occupies in `Benchmark.png`, so nothing is stretched or guessed.

**Adding an archetype means one more case, not another system.**
`Kind.config` holds awareness speed, how long they stay distracted, how long a robbery takes, plus
the colour wash and the badge symbol. The awareness and steal systems are the same for everybody.
Want an "Anxious" or a "Child"? Add a `case`, fill in `Config`, done — `Game.tick` stays untouched.

**All the balancing numbers live in `enum Tune` and `Kind.config`.** Round length, road speed,
awareness decay, the penalty for changing seats, how long a robbery takes per archetype. No magic
numbers hidden in the view.

**All the seats are defined in one place.** `Layout.seats` is an array of `SeatSpec`: which bench,
where the seat sprite goes, and the baseline the sitting sprite rests on. Want to add or move a
seat? Change that array — the drawing, the tap target, the empty marker and the adjacency rules all
follow.

**You can rob more than one person at a time.** `Game.steals` is `[seat: progress]`, not a single
target. Each target has its own progress and its own awareness. In the view every seat uses
`simultaneousGesture` (not `gesture`) so two of them can be held together. With one finger it
behaves exactly like a single target — nothing changes.

**Passengers come and go by themselves.** Each one carries `rideLeft`. When it runs out they get
off, robbed or not. The seat stays empty for a random `Tune.boardWait`, then a new passenger boards
with a random archetype that is not the same as their neighbour's. If the thief is sitting there,
the new passenger waits until the thief moves.

**Passenger state machine:** `busy → waking → alert → busy`.
`waking` is a short warning window — you still have time to let go. Awareness climbs slowly while
they are `busy` and fast while they are `alert`. When nobody is robbing them it drains on its own.
The two chatters get fixed (not random) timings so they stop talking at the same moment.

**Logic is separate from presentation.** `Game` is a plain struct with no SwiftUI. `runGameChecks()`
at the bottom of `Game.swift` exercises the seat rules, adjacency, a success, getting caught and the
round running out — it runs on every launch in DEBUG, so the app crashes immediately if a rule breaks.

**One 60fps `Timer` drives the game loop**, not `TimelineView`. Everything that moves (the road, the
clock, awareness) advances from the same `Game.tick(dt)`, which makes it easy to pause and to test.

## Audio notes

The SFX are **generated placeholders**, not recordings — `sfx_success` (item lifted), `sfx_caught`
(spotted), `sfx_move` (seat change), `sfx_win` (made it to your stop). Drop the real `.wav` files
into `Resources/Audio` under the same names; no code changes needed.

The session is `.ambient` + `.mixWithOthers`: it respects the silent switch and does not cut the
player's own music. If you later want sound even on silent, switch to `.playback` in `Audio.init`.

## Art notes

Everything in the game comes from `Placeholder/`, the team's own hand-drawn placeholder set.
`Benchmark.png` is the reference composition — the road, the bus, the seats and the characters are
all placed at exactly the coordinates they occupy there, so the running game and the reference match
pixel for pixel.

| Asset | Source file | Used for |
|---|---|---|
| `road` | `Jalan.png` | the scrolling road, tiled with a 2557px period |
| `angkot` | `Angkot.png` | the bus body — it has no seats drawn in, they are separate sprites |
| `seat_far` / `seat_near` | `KursiKiri.png` / `KursiKanan.png` | the two benches |
| `seat_folding` / `kid` | `KursiExtra.png` / `Bocah.png` | the folding seat by the door, scenery |
| `driver` | `Sopir.png` | the driver, scenery |
| `thief` | `Pencipet.png` | the player |
| `victim_far` / `victim_near` | `VictimKiri.png` / `VictimKanan.png` | every passenger |

What this placeholder set does not have yet, and how the game covers for it:

- **One passenger drawing per bench, with no per-archetype or per-state variants.** The archetype is
  carried by a colour wash (`Kind.config.tint`, the same idea as the red and blue victims in
  `Benchmark.png`) and the state by the badge above the head (`Kind.config.busySymbol` while they are
  distracted, then an eye while waking, a filled eye while alert). Swap in real per-state drawings
  later and the tint and the badge can go.
- **One thief drawing, front view, with no reaching or sliding pose.** It is drawn once and slid
  between seats, and it leans `Tune.reach` towards whoever is being robbed. On the near bench it
  still faces the camera while everybody else faces away.
- **Nothing is mirrored.** The old art had a reach pose that had to be flipped; none of these
  drawings do.

## Deliberately missing

Background music, a main menu, high scores, more than one life. Getting caught ends the round right
away, which keeps it to one code path and keeps the tension up.
