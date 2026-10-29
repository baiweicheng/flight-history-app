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
    func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func assertMetricsVisible(_ app: XCUIApplication) {
        for id in ["metricFlights", "metricTime", "metricAirports"] {
            let metric = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(metric.exists, id)
            XCTAssertGreaterThan(metric.frame.width, 20, id + " must not collapse")
            XCTAssertTrue(metric.isHittable, id + " must be visible")
        }
    }
    func chooseAirports(_ app: XCUIApplication, from: String, to: String) {
        for (field, code) in [("originAirport", from), ("destinationAirport", to)] {
            app.buttons[field].tap()
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap(); search.typeText(code)
            let result = app.buttons["airport-" + code].firstMatch
            XCTAssertTrue(result.waitForExistence(timeout: 15)); result.tap()
        }
    }
    func testFastBackfillDuplicateWarningAndCustomDates() {
        let app = XCUIApplication(); app.launchArguments = ["-uitesting", "-reset-test-data"]; app.launch()
        XCTAssertTrue(app.buttons["addFlight"].waitForExistence(timeout: 15)); app.buttons["addFlight"].tap()
        chooseAirports(app, from: "JFK", to: "LHR"); app.buttons["saveFlight"].tap()
        app.buttons["addFlight"].tap(); chooseAirports(app, from: "JFK", to: "LHR")
        app.swipeUp()
        let warning = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'A flight on this route and date'")).firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 5)); capture(app, "Nonblocking duplicate warning")
        app.buttons["Save and add another"].tap()
        app.swipeDown(); app.swipeDown()
        XCTAssertEqual(app.buttons["originAirport"].value as? String, "Not selected")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["2"].exists)
        app.buttons["dateFilter"].tap(); app.buttons["customDates"].tap()
        app.buttons["Apply custom range"].tap()
        XCTAssertTrue(app.staticTexts["2"].exists)
        let range = app.buttons["dateFilter"].label
        XCTAssertFalse(range.contains("All time"))
        app.tabBars.buttons["Flights"].tap(); XCTAssertEqual(app.buttons["dateFilter"].label, range)
        app.tabBars.buttons["Map"].tap(); XCTAssertEqual(app.buttons["dateFilter"].label, range)
    }
    func openDataTransfer(_ app: XCUIApplication) {
        app.buttons["Settings"].tap()
        app.buttons["Backup & export"].tap()
        XCTAssertTrue(app.buttons["exportBackup"].waitForExistence(timeout: 5))
    }
    func testBackupPreviewReplaceRecoveryAndInvalidData() {
        let app = seededApp()
        openDataTransfer(app)
        app.buttons["previewTestBackup"].tap()
        XCTAssertTrue(app.staticTexts["restoreResult"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["restoreResult"].label.contains("8"))
        app.buttons["Replace"].tap()
        XCTAssertTrue(app.staticTexts["restoreResult"].label.contains("2"))
        capture(app, "Restore preview")
        app.buttons["applyRestore"].tap()
        app.sheets.buttons["Replace log"].tap()
        XCTAssertTrue(app.buttons["recoverLog"].waitForExistence(timeout: 5))
        app.buttons["recoverLog"].tap()
        app.buttons["Replace"].tap()
        XCTAssertTrue(app.staticTexts["restoreResult"].label.contains("8"))
        app.buttons["applyRestore"].tap(); app.sheets.buttons["Replace log"].tap()
        let dismissed = expectation(for: NSPredicate { _, _ in !app.buttons["applyRestore"].exists }, evaluatedWith: app)
        wait(for: [dismissed], timeout: 10)
        app.swipeUp()
        let invalid = app.buttons["Check invalid test backup"]
        XCTAssertTrue(invalid.waitForExistence(timeout: 5)); invalid.tap()
        XCTAssertTrue(app.alerts["Data transfer couldn’t finish"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
    }
    func testDeleteUndoAndReturnEntry() {
        let app = seededApp()
        app.tabBars.buttons["Flights"].tap()
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'SFO → JFK'")).firstMatch.tap()
        app.swipeUp()
        app.buttons["Add return flight"].tap()
        XCTAssertEqual(app.buttons["originAirport"].value as? String, "JFK")
        XCTAssertEqual(app.buttons["destinationAirport"].value as? String, "SFO")
        capture(app, "Return entry with separate date")
        app.buttons["saveFlight"].tap()
        app.swipeUp()
        app.buttons["Delete flight"].tap(); app.sheets.buttons["Delete flight"].tap()
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5)); app.buttons["Undo"].tap()
        app.tabBars.buttons["Overview"].tap()
        XCTAssertTrue(app.staticTexts["9"].exists)
    }
    func testNativeExportSheetAndScreenshots() {
        let app = seededApp()
        capture(app, "Overview light")
        app.tabBars.buttons["Map"].tap()
        capture(app, "All routes map")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'JFK ↔ NRT'")).firstMatch.tap()
        capture(app, "Pacific selected")
        openDataTransfer(app)
        app.buttons["exportBackup"].tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 30), app.debugDescription)
        capture(app, "Native backup export")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Export saved."].waitForExistence(timeout: 15))
        app.buttons["exportCSV"].tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 30))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Export saved."].waitForExistence(timeout: 15))
        app.buttons["restoreBackup"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 30), app.debugDescription)
        capture(app, "Native restore file picker")
        app.tabBars.buttons["Browse"].tap()
        let location = app.cells["DOC.sidebar.item.On My iPhone"]
        let file = app.cells.matching(NSPredicate(format: "label BEGINSWITH 'Flightbook-' AND enabled == true")).firstMatch
        let loaded = expectation(for: NSPredicate { _, _ in location.exists || file.exists }, evaluatedWith: app)
        wait(for: [loaded], timeout: 15)
        if location.exists { location.tap() }
        XCTAssertTrue(file.waitForExistence(timeout: 10), app.debugDescription)
        file.tap()
        XCTAssertTrue(app.staticTexts["restoreResult"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["restoreResult"].label.contains("8"))
        app.buttons["applyRestore"].tap()
    }
    func testAccessibilityLargeTypeAndDarkAppearance() throws {
        let app = seededApp()
        assertMetricsVisible(app)
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .dynamicType])
        app.buttons["Settings"].tap()
        app.buttons["unitPicker"].tap(); app.buttons["Kilometers"].tap()
        app.buttons["appearancePicker"].tap(); app.buttons["Dark"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["totalDistance"].label.hasSuffix("km"))
        capture(app, "Overview dark")
        app.terminate()
        app.launchArguments = ["-uitesting", "-seed-uat", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["addFlight"].waitForExistence(timeout: 15))
        capture(app, "Overview accessibility XXXL")
        app.buttons["addFlight"].tap()
        XCTAssertTrue(app.buttons["originAirport"].exists)
        capture(app, "Flight form accessibility XXXL")
    }

    func testSharedFiltersAndIndependentAnnualYear() {
        let app = seededApp()
        app.buttons["dateFilter"].tap()
        app.buttons["2025"].tap()
        XCTAssertTrue(app.staticTexts["2"].exists)
        app.tabBars.buttons["Flights"].tap()
        XCTAssertTrue(app.buttons["dateFilter"].label.contains("2025"))
        app.tabBars.buttons["Annual"].tap()
        let currentYear = String(Calendar(identifier: .gregorian).component(.year, from: .now))
        XCTAssertTrue(app.buttons["annualYear"].label.contains(currentYear))
        if currentYear == "2026" { assertMetricsVisible(app) }
        capture(app, "Annual summary current year")
        app.buttons["annualYear"].tap(); app.buttons["2025"].tap()
        app.swipeUp()
        capture(app, "Annual monthly activity and highlights")
        let shortest = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Shortest flight'")).firstMatch
        XCTAssertTrue(shortest.waitForExistence(timeout: 5)); shortest.tap()
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.swipeDown()
        XCTAssertTrue(app.buttons["annualYear"].label.contains("2025"))
        app.tabBars.buttons["Overview"].tap()
        XCTAssertTrue(app.buttons["dateFilter"].label.contains("2025"))
        app.tabBars.buttons["Annual"].tap()
        XCTAssertTrue(app.buttons["annualYear"].label.contains(currentYear))
    }

    func testMapZoomPanPinchFocusAndCameraRetention() throws {
        let app = seededApp()
        app.tabBars.buttons["Map"].tap()
        let map = app.images["routeMap"]
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription])
        let baseline = map.value as? String
        app.buttons["zoomIn"].tap()
        XCTAssertNotEqual(map.value as? String, baseline)
        map.swipeLeft(velocity: .slow)
        map.pinch(withScale: 1.5, velocity: 1)
        XCTAssertFalse(app.buttons["View flights"].exists, "Map gestures must not select a route")
        let zoomed = map.value as? String
        app.tabBars.buttons["Flights"].tap(); app.tabBars.buttons["Map"].tap()
        XCTAssertEqual(map.value as? String, zoomed)
        app.buttons["focusRoutes"].tap()
        let focused = expectation(for: NSPredicate { _, _ in map.value as? String == baseline }, evaluatedWith: map)
        wait(for: [focused], timeout: 5)
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
