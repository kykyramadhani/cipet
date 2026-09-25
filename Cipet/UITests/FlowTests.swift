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

    // every bench seat, as a passenger (to pick) and as a place to sit, with the angkot 20 lower
    private let people: [(CGFloat, CGFloat)] = [(289, 173), (350, 173), (412, 173),
                                                (292, 249), (357, 249), (415, 249)]
    private let seats: [(CGFloat, CGFloat)] = [(289, 171), (350, 171), (412, 171),
                                               (292, 254), (357, 254), (415, 254)]

    func testFirstGameThenHoldAnywhere() {
        XCUIDevice.shared.orientation = .landscapeLeft
        // as if it's the first Play ever, whatever an earlier run left behind
        app.launchArguments = ["-hasCompletedTutorial", "NO"]
        app.launch()

        // menu -> Play goes straight into the tutorial, not round 1
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 20))
        app.buttons["Play"].tap()
        sleep(1)
        XCTAssertFalse(app.buttons["Start"].exists, "the tutorial comes before the round card")

        var page = 1
        while app.buttons["tutorial-next"].waitForExistence(timeout: 3) {
            snap("tutorial-\(page)")
            app.buttons["tutorial-next"].tap()
            page += 1
            sleep(1)
        }
        snap("tutorial-\(page)")
        XCTAssertEqual(page, 6, "six tutorial screens")
        app.buttons["tutorial-play"].tap()

        // round 1's card counts itself down into pick target, there's no Start to press
        sleep(1)
        snap("round-1")
        XCTAssertFalse(app.buttons["Start"].exists, "the round card runs on its own")
        let confirm = app.buttons["Confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 15), "tutorial done, round 1, then pick")
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

        // done once, it's done for good: a fresh launch goes from Play straight to round 1
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 20))
        app.buttons["Play"].tap()
        XCTAssertFalse(app.buttons["tutorial-next"].waitForExistence(timeout: 3), "the tutorial came back")
        XCTAssertTrue(app.buttons["Confirm"].waitForExistence(timeout: 15), "straight into round 1")
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: self)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}
