import SwiftUI

// two stages, and only Confirm moves between them. until then the target (and then the
// seat) can be changed as often as you like.
@Observable final class PickVictimViewModel {
    enum Stage { case target, seat }

    let cast: Arrangement
    private(set) var stage: Stage = .target
    private(set) var target: Seating.Person?
    private(set) var seat: CGRect?

    /// set by the router, which is the only thing that arms it
    var tutorialUp = false

    init(cast: Arrangement) { self.cast = cast }

    var prompt: String {
        switch stage {
        case .target: return "Choose your target"
        case .seat:   return seat == nil ? "Now, pick the seat!" : "Confirm if you\u{2019}re ready!"
        }
    }

    /// he waits on the kerb while you're still browsing targets
    var onPavement: Bool { stage == .target }

    /// the empty seats beside whoever is picked, recalculated every time the pick changes
    var seatsOnOffer: [CGRect] { target.map(cast.seats(beside:)) ?? [] }

    /// the faded markers: every seat on offer except the one he's already sat in
    var ghosts: [CGRect] { seatsOnOffer.filter { $0 != seat } }

    var canConfirm: Bool {
        switch stage {
        case .target: return !seatsOnOffer.isEmpty   // nowhere to sit, nothing to confirm
        case .seat:   return seat != nil
        }
    }

    /// switching targets drops the old one and its seats. only before the first Confirm.
    func pick(_ v: Seating.Person) {
        // the kid and the driver are on screen but off limits, whatever gets tapped
        guard !tutorialUp, stage == .target, cast.targets.contains(v), v != target else { return }
        target = v
        seat = nil
        Audio.shared.play(.click)
    }

    /// and the same for seats, once the target is locked
    func take(seat spot: CGRect) {
        guard !tutorialUp, stage == .seat, seatsOnOffer.contains(spot), spot != seat else { return }
        seat = spot
        Audio.shared.play(.seated)
    }

    /// the first press locks the target. one seat beside them and he just takes it, so this
    /// hands back the finished choice straight away; two and it waits for you to pick one.
    func confirm() -> (target: Seating.Person, seat: CGRect)? {
        guard !tutorialUp, canConfirm, let target else { return nil }
        switch stage {
        case .target:
            let seats = seatsOnOffer
            guard seats.count == 1 else {
                stage = .seat
                return nil
            }
            seat = seats[0]
            Audio.shared.play(.seated)
            return (target, seats[0])
        case .seat:
            return seat.map { (target, $0) }
        }
    }

    func tutorialFinished() { tutorialUp = false }
}

func runPickChecks() {
    #if DEBUG
    let fixed = Arrangement.fixed
    let near = fixed.seats(beside: .nearMid)
    assert(near.count == 2 && fixed.seats(beside: .farLeft).count == 1,
           "the checks below need one two-seat target and one one-seat target")

    // browsing: nothing to confirm yet, then every tap swaps the target and its seats
    let vm = PickVictimViewModel(cast: fixed)
    assert(!vm.canConfirm && vm.seatsOnOffer.isEmpty)
    vm.pick(.kid)
    assert(vm.target == nil, "the kid cant be picked")
    vm.pick(.farMid)
    assert(vm.target == nil, "nor an empty seat")
    vm.pick(.nearMid)
    assert(vm.target == .nearMid && vm.seatsOnOffer == near && vm.canConfirm)
    vm.pick(.farLeft)
    assert(vm.target == .farLeft && vm.seatsOnOffer == fixed.seats(beside: .farLeft),
           "switching drops the old target's seats")
    vm.pick(.nearMid)
    assert(vm.target == .nearMid && vm.stage == .target, "and you can go back, nothing's locked")

    // two seats: the first Confirm locks the target and asks for a seat
    assert(vm.confirm() == nil && vm.stage == .seat, "two seats means choosing one")
    assert(!vm.canConfirm && vm.prompt == "Now, pick the seat!")
    vm.pick(.farLeft)
    assert(vm.target == .nearMid, "the target is locked now")
    vm.take(seat: fixed.seats(beside: .farLeft)[0])
    assert(vm.seat == nil, "only seats beside the target count")
    vm.take(seat: near[0])
    vm.take(seat: near[1])
    assert(vm.seat == near[1] && vm.ghosts == [near[0]], "the seat can change, the other stays offered")
    vm.take(seat: near[0])
    assert(vm.seat == near[0], "and change back")
    let done = vm.confirm()
    assert(done?.target == .nearMid && done?.seat == near[0], "the second Confirm hands it over")

    // one seat: Confirm sits him straight down, no seat stage at all
    let one = PickVictimViewModel(cast: fixed)
    one.pick(.farRight)
    let straight = one.confirm()
    assert(straight?.target == .farRight && straight?.seat == fixed.seats(beside: .farRight)[0])
    assert(one.stage == .target, "never went through picking a seat")

    // no seats: somebody boxed in on a full bench can be looked at but not confirmed
    let boxed = PickVictimViewModel(cast: Arrangement(cast: [.farLeft: .frontA, .farMid: .frontB,
                                                             .farRight: .frontA, .nearMid: .backA]))
    boxed.pick(.farMid)
    assert(boxed.target == .farMid && !boxed.canConfirm && boxed.confirm() == nil)
    assert(boxed.stage == .target, "so you stay put and pick someone else")

    // nothing happens while the tutorial is up
    let busy = PickVictimViewModel(cast: fixed)
    busy.tutorialUp = true
    busy.pick(.nearMid)
    assert(busy.target == nil && busy.confirm() == nil)
    #endif
}
