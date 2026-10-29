import XCTest

@MainActor final class FlightbookUITests: XCTestCase {
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
