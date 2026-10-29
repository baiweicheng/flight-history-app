import XCTest
@testable import FlightbookCore

final class BackupTests: XCTestCase {
    func fixture() throws -> Flight {
        let a = Airport(id: "1", ident: "KJFK", iata: "JFK", name: "John F. Kennedy", city: "New York", country: "US", latitude: 40.64, longitude: -73.77, kind: "large_airport", sourceVersion: "catalog-1")
        var b = a; b.id = "2"; b.ident = "EGLL"; b.iata = "LHR"; b.latitude = 51.47; b.longitude = -0.45
        var f = Flight(origin: a, destination: b, departure: try LocalDate(iso: "1999-12-31"))
        f.notes = "A memory, with \"quotes\"\r\nand a new line"; f.flightNumber = "AB123"; f.airline = "Example"
        f.corrections = [Measurement(value: 390, unit: "minutes", basis: .airborne, kind: .userSupplied, provider: "User", version: "1")]
        return f
    }
    func testBackupIsLosslessAndKeepsMetricsIdentityAndCorrections() throws {
        let f = try fixture(), data = try BackupCodec.encode([f])
        let backup = try BackupCodec.decode(data)
        XCTAssertEqual(backup.flights, [f])
        XCTAssertEqual(Statistics(backup.flights).distanceKM, Statistics([f]).distanceKM)
        XCTAssertEqual(Statistics(backup.flights).minutes, 390)
        XCTAssertEqual(backup.flights[0].corrections[0].id, f.corrections[0].id)
        XCTAssertEqual(try BackupCodec.decode(BackupCodec.encode([])).flights.count, 0)
    }
    func testRouteEditsArchiveMeasurementsAndRetainFlightIdentity() throws {
        var f = try fixture()
        let before = f, correction = f.corrections[0]
        var c = f.destination; c.id = "3"; c.ident = "NRT"; c.iata = "NRT"; c.latitude = 35.77; c.longitude = 140.39
        f.reviseRoute(origin: f.origin, destination: c)
        XCTAssertEqual(f.id, before.id); XCTAssertEqual(f.createdAt, before.createdAt)
        XCTAssertTrue(f.corrections.isEmpty)
        XCTAssertEqual(f.metricHistory?.first?.corrections, [correction])
        XCTAssertEqual(f.metricHistory?.first?.destination, before.destination)
        XCTAssertEqual(try BackupCodec.decode(BackupCodec.encode([f])).flights, [f])
    }
    func testCorruptionDuplicatesInvalidDatesAndNewerVersionsAreRejected() throws {
        let f = try fixture(), data = try BackupCodec.encode([f])
        let json = String(decoding: data, as: UTF8.self)
        for corrupted in [json.replacingOccurrences(of: "AB123", with: "AB456"),
                          json.replacingOccurrences(of: "1999-12-31", with: "1999-02-30"), "{\"flights\":[]}", "not json"] {
            XCTAssertThrowsError(try BackupCodec.decode(Data(corrupted.utf8)))
        }
        XCTAssertThrowsError(try BackupCodec.encode([f,f]))
        XCTAssertThrowsError(try BackupCodec.make([f], at: Date(timeIntervalSince1970: 1e100)))
        XCTAssertThrowsError(try BackupCodec.decode(Data("{\"format\":\"flightbook\",\"schemaVersion\":99}".utf8))) { error in
            XCTAssertEqual(error as? FlightError, .unsupportedVersion)
        }
    }
    func testMergeKeepsLocalCorrectionsAndWarnsAboutDuplicateLegs() throws {
        let local = try fixture()
        var edited = local; edited.notes = "A different version from an older backup"
        var anotherLeg = local; anotherLeg.id = UUID()
        let plan = RestorePlan(existing: [local], incoming: [edited,anotherLeg], mode: .merge)
        XCTAssertEqual(plan.conflicts, 1); XCTAssertEqual(plan.added, 1); XCTAssertEqual(plan.possibleDuplicates, 1)
        XCTAssertEqual(plan.resultingFlights.first { $0.id == local.id }, local)
        XCTAssertEqual(RestorePlan(existing: [local], incoming: [local], mode: .merge).unchanged, 1)
        let replace = RestorePlan(existing: [local], incoming: [edited], mode: .replace)
        XCTAssertEqual(replace.resultingFlights, [edited])
    }
    func testCSVQuotesNewlinesAndProtectsSpreadsheetCells() throws {
        var f = try fixture()
        f.notes = " =HYPERLINK(\"https://example.test\")"
        let csv = CSVExport.encode([f])
        XCTAssertTrue(csv.contains("\"' =HYPERLINK(\"\"https://example.test\"\")\""))
        f.notes = "First, \"quoted\"\r\nsecond line"
        XCTAssertTrue(CSVExport.encode([f]).contains("\"First, \"\"quoted\"\"\r\nsecond line\""))
        XCTAssertTrue(csv.hasSuffix("\r\n")); XCTAssertTrue(csv.contains(f.id.uuidString))
        XCTAssertTrue(csv.contains("\"-73.77\"")); XCTAssertFalse(csv.contains("\"'-73.77\""))
    }
}
