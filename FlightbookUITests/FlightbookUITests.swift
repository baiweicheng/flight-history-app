import XCTest

@MainActor final class FlightbookUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func seededApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting", "-reset-test-data", "-seed-uat"]
        app.launch()
        XCTAssertTrue(app.buttons["dateFilter"].waitForExistence(timeout: 20))
        return app
    }

    func testSharedFiltersAndIndependentAnnualYear() {
        let app = seededApp()
        app.buttons["dateFilter"].tap()
        app.buttons["2025"].tap()
        XCTAssertTrue(app.staticTexts["2"].exists)
        app.tabBars.buttons["Flights"].tap()
        XCTAssertTrue(app.buttons["dateFilter"].label.contains("2025"))
        app.tabBars.buttons["Annual"].tap()
        XCTAssertTrue(app.buttons["annualYear"].label.contains("2026"))
        app.buttons["annualYear"].tap(); app.buttons["2025"].tap()
        app.swipeUp()
        let shortest = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Shortest flight'")).firstMatch
        XCTAssertTrue(shortest.waitForExistence(timeout: 5)); shortest.tap()
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.swipeDown()
        XCTAssertTrue(app.buttons["annualYear"].label.contains("2025"))
        app.tabBars.buttons["Overview"].tap()
        XCTAssertTrue(app.buttons["dateFilter"].label.contains("2025"))
        app.tabBars.buttons["Annual"].tap()
        XCTAssertTrue(app.buttons["annualYear"].label.contains("2026"))
    }

    func testMapZoomPanPinchFocusAndCameraRetention() {
        let app = seededApp()
        app.tabBars.buttons["Map"].tap()
        let map = app.images["routeMap"]
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        let baseline = map.value as? String
        app.buttons["zoomIn"].tap()
        XCTAssertNotEqual(map.value as? String, baseline)
        map.swipeLeft(velocity: .slow)
        map.pinch(withScale: 1.5, velocity: 1)
        let zoomed = map.value as? String
        app.tabBars.buttons["Flights"].tap(); app.tabBars.buttons["Map"].tap()
        XCTAssertEqual(map.value as? String, zoomed)
        app.buttons["focusRoutes"].tap()
        XCTAssertEqual(map.value as? String, baseline)
        app.swipeUp()
        let pacific = app.buttons.matching(NSPredicate(format: "label CONTAINS 'JFK ↔ NRT'")).firstMatch
        XCTAssertTrue(pacific.waitForExistence(timeout: 5)); pacific.tap()
        app.buttons.matching(NSPredicate(format: "label == 'View flights'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'NRT'")).firstMatch.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Pacific route drilldown"; shot.lifetime = .keepAlways; add(shot)
    }

    func testAddFlightSurvivesRelaunchAndEdit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting", "-reset-test-data"]
        app.launch()
        XCTAssertTrue(app.buttons["addFlight"].waitForExistence(timeout: 15))
        app.buttons["addFlight"].tap()
        app.buttons["originAirport"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap(); search.typeText("JFK")
        let jfk = app.buttons["airport-JFK"].firstMatch
        XCTAssertTrue(jfk.waitForExistence(timeout: 15)); jfk.tap()
        app.buttons["destinationAirport"].tap()
        search.tap(); search.typeText("LHR")
        let lhr = app.buttons["airport-LHR"].firstMatch
        XCTAssertTrue(lhr.waitForExistence(timeout: 15)); lhr.tap()
        app.buttons["saveFlight"].tap()
        XCTAssertTrue(app.staticTexts["totalDistance"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'JFK → LHR'")).firstMatch.exists)
        app.terminate()
        app.launchArguments = ["-uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["totalDistance"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Flights"].tap()
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'JFK → LHR'")).firstMatch.tap()
        app.buttons["Edit"].tap()
        app.buttons["Swap airports"].tap()
        app.buttons["saveFlight"].tap()
        XCTAssertTrue(app.staticTexts["LHR → JFK"].waitForExistence(timeout: 5))
    }
}
