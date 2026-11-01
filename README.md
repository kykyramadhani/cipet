# Cipet!

**A pickpocketing game for iPhone, set inside an angkot.**

You are a thief on a crowded angkot (the shared minibus common across Indonesia). Pick a target,
pick your seat, then hold your finger down to steal while the passengers around you slowly start
to notice. Read their faces, wait for the right moment, and get out before somebody catches you.

Made for an Apple Developer Academy game jam. Built with SwiftUI, no game engine and no
third-party code.

| | |
|---|---|
| Platform | iPhone, landscape only |
| Minimum iOS | 17.0 |
| Language | Swift 5, SwiftUI |
| Languages in game | English and Indonesian (switch inside the game) |
| Bundle ID | `com.gamejam.cipet` |

## How to play

1. **Tutorial.** The first time you press Play you get a six page tutorial. After that it never
   comes back.
2. **Choose your target.** Tap the passenger you want to rob.
3. **Pick your seat.** Choose the seat you want to make your move from.
4. **Steal.** Hold your finger anywhere on the screen. The steal bar fills while you hold. Let go
   and it drops again.
5. **Watch the passengers.** Each passenger has a suspicion bar that only shows up when they are
   awake and paying attention. If a bar fills, you get a strike and a short cooldown where you
   cannot steal. Three strikes and you go to jail.
6. **Beat the clock.** Every round is 60 seconds. Fill the steal bar in time and you keep the
   item. Run out of time and the round is failed.
7. **Keep going.** Win a round and you can go to the next one, which is a little harder. Or end the
   game and see your total.

Your best round and your highest total are saved between launches and shown on the Record button
on the main menu.

### The passengers

Passengers behave differently, and you read their state from how they look and move: headphones,
head movement, and changing faces. You rarely need the text.

- **Sleepy.** Dozing off, so easier to rob while they sleep.
- **Music.** Listening to music and tuned out from everything around them.
- **Duo.** Two friends talking to each other, not watching anyone else.
- **The kid.** Always on board, and slow to notice, but not a free pass.

Each passenger goes between calm, alert, and angry, with its own animation for every change. A calm
passenger does not notice you at all. An alert one starts building suspicion. One who catches you
turns angry.

### Rewards

Each steal is worth a random amount between Rp 5k and Rp 1 JT. Amounts under a million are written
like `Rp 999k`, and above that like `Rp 1,5 JT`.

## Running it

You need Xcode with an iOS 17 (or newer) simulator or device.

```bash
git clone https://github.com/kykyramadhani/cipet.git
cd cipet/Cipet
open Cipet.xcodeproj
```

Pick an iPhone, press Run, and turn the phone to landscape.

If you change `project.yml`, regenerate the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
cd Cipet
xcodegen generate
```

## Features

- **Hold anywhere to steal.** Touches are read as soon as a finger lands, anywhere on the screen
  except the HUD, so the hold starts right away.
- **Haptic feedback.** A steady buzz for as long as you hold. Its strength is a slider in Settings.
  Set it to 0 to turn it off.
- **Passenger awareness.** Passengers start calm, become alert, and get angry only when you are
  caught. Their suspicion bars are driven by how they are animated, not by a hidden timer.
- **Difficulty that grows.** Each round deals every passenger their own numbers, and the game gets
  a little harder every few rounds on a fixed schedule.
- **A live tutorial.** Built from the same art and layout as the real game, not screenshots.
- **Two languages.** English and Indonesian, switched inside the game, separate from the phone's
  own language.
- **Settings.** SFX volume, music volume, haptic strength, and language.
- **Record.** Highest round and top total value, kept between launches.
- **End screens.** Jailed, Failed, and Congrats all offer Play Again and Back to Main Menu.

## How it is built

Screens go one way: **loading, menu, tutorial (first game only), countdown, pick target, steal,
then end of game.**

- **One fixed design canvas.** Every screen is laid out on a canvas of 874 by 402 and then scaled
  to fit the device, so a layout looks the same on any iPhone.
- **Game logic is separate from drawing.** The steal itself runs on a 60 times a second tick inside
  a view model. The views only draw what the view model says.
- **Animation from frame sets.** Characters are numbered image sequences in the asset catalog. The
  list of sets is written into the app at build time, so adding a new animation needs no code.
- **Passenger moods.** Every passenger has calm, alert and angry looks, and the game finds its own
  way between them and plays each change once.
- **Sound and haptics are off the main thread.** Sound effects run on their own queue, and the
  haptic buzz uses Core Haptics, so neither can slow down a touch.
- **No SpriteKit.** Everything is SwiftUI.

### Project layout

```
Cipet/
  project.yml              XcodeGen project definition
  Sources/
    App/                   app entry, screen routing, rounds, passengers
    Loading/ Menu/         loading screen, main menu, settings, record, instructions
    Tutorial/              the live tutorial
    Countdown/             round countdown
    PickVictim/            choosing a target and a seat
    Steal/                 the steal itself, thief, jail screen, overlays
    EndGame/               congrats, jailed, and failed screens
    Audio/                 sound effects and music
    Shared/                layout, animation, haptics, language, records, styles
  Resources/
    Assets.xcassets        art and animation frames
    Audio/                 sound effects and music
    Fonts/                 Skranji (SIL Open Font License)
    Localizable.xcstrings  every word in the game, English and Indonesian
  UITests/                 end to end test of the first game
```

## Tests

Debug builds run a set of built-in checks at launch (layout, rules, scaling, text), and the app
stops right away if one of them fails.

There is also a UI test that plays through a first game with real touches: tutorial, choosing a
target and seat, and holding to steal.

```bash
cd Cipet
xcodebuild -project Cipet.xcodeproj -scheme Cipet \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Touch timing and haptics only feel right on a real phone, so test those on a device.

## Credits

- Font: [Skranji](https://fonts.google.com/specimen/Skranji), licensed under the SIL Open Font
  License (see `Cipet/Resources/Fonts/OFL.txt`).
