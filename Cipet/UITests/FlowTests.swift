import XCTest

// plays the start of a first game with real touches: Play, every tutorial page, round 1's
// countdown, picking a target and a seat, then stealing by holding on empty road nowhere
// near the bar. it saves a screenshot at each step for checking against the design.
final class FlowTests: XCTestCase {
    private let app = XCUIApplication()
    private let shots = ProcessInfo.processInfo.environment["FLOW_SHOTS"]

    /// a point in the game's 874x402 design space. the game covers the screen the same way
    /// on any phone, so a normalised point on the window lands on the same spot.
    private func at(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: x / 874, dy: y / 402))
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: shot)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        if let shots { try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/\(name).png")) }
    }

    // where the next arrow sits on each tutorial page, then Play now on the last
    private let nexts: [(CGFloat, CGFloat)] = [(826, 295), (826, 316), (806, 267), (828, 266),
                                               (284, 360), (278, 357), (828, 347), (189, 307)]

    // every bench seat, as a passenger (to pick) and as a place to sit, with the angkot 20 lower
    private let people: [(CGFloat, CGFloat)] = [(289, 173), (350, 173), (412, 173),
                                                (292, 249), (357, 249), (415, 249)]
    private let seats: [(CGFloat, CGFloat)] = [(289, 171), (350, 171), (412, 171),
                                               (292, 254), (357, 254), (415, 254)]

    func testFirstGameThenHoldAnywhere() {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()

        // menu -> Play goes straight into the tutorial, not round 1
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 20))
        app.buttons["Play"].tap()
        sleep(1)
        XCTAssertFalse(app.buttons["Start"].exists, "the tutorial comes before the round card")

        for (i, p) in nexts.enumerated() {
            snap("tutorial-\(i + 1)")
            at(p.0, p.1).tap()
            sleep(1)
        }

        // round 1, then its countdown into pick target
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5), "tutorial done, round 1")
        snap("round-1")
        app.buttons["Start"].tap()
        let confirm = app.buttons["Confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        sleep(1)
        snap("pick-target")

        // pick whoever turns Confirm on first, then a seat if it asks for one
        for p in people where !confirm.isEnabled { at(p.0, p.1).tap() }
        XCTAssertTrue(confirm.isEnabled, "somebody on board has to be pickable")
        confirm.tap()
        sleep(1)
        if confirm.exists {
            for s in seats where !confirm.isEnabled { at(s.0, s.1).tap() }
            confirm.tap()
        }
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5), "into the steal")
        sleep(1)
        snap("steal-before")

        // hold on the road in the bottom left, nowhere near the bar
        at(110, 360).press(forDuration: 2.5)
        snap("steal-after-hold-bottom-left")
        // and up by the wallet, and on a passenger's head
        at(90, 110).press(forDuration: 1.5)
        snap("steal-after-hold-top-left")

        // paused, holding does nothing
        at(820, 54).tap()
        sleep(1)
        snap("paused")
        at(110, 360).press(forDuration: 2)
        snap("paused-after-hold")
        XCTAssertTrue(app.buttons["Resume"].exists)
        app.buttons["Resume"].tap()
        sleep(1)
        at(110, 360).press(forDuration: 1.5)
        snap("resumed-after-hold")
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: self)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}
