import XCTest
@testable import FlightbookCore

final class FlightTests: XCTestCase {
    func airport(_ id: String, _ lat: Double, _ lon: Double) -> Airport {
        Airport(id: id, ident: id, iata: id, name: id + " Airport", city: id, country: "US",
                latitude: lat, longitude: lon, kind: "large_airport", sourceVersion: "test")
    }
    var jfk: Airport { airport("JFK", 40.6413, -73.7781) }
    var lhr: Airport { airport("LHR", 51.47, -0.4543) }
    var nrt: Airport { airport("NRT", 35.772, 140.3929) }
    func flight(_ a: Airport, _ b: Airport, _ date: String = "2026-05-13") throws -> Flight {
        Flight(origin: a, destination: b, departure: try LocalDate(iso: date))
    }
    func testLocalDateValidationAndLosslessEncoding() throws {
        for invalid in ["2025-02-29", "2026-04-31", "2026-00-10", "2026-13-01", "2026-1-01", "0000-01-01", "2026-01-00"] {
            XCTAssertThrowsError(try LocalDate(iso: invalid), invalid)
        }
        let leap = try LocalDate(iso: "2024-02-29")
        XCTAssertEqual(try JSONDecoder().decode(LocalDate.self, from: JSONEncoder().encode(leap)), leap)
        for zone in ["America/New_York", "Pacific/Kiritimati", "Pacific/Honolulu"] {
            var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: zone)!
            let d = c.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12))!
            XCTAssertEqual(LocalDate(d, calendar: c).description, "2026-11-01")
        }
    }
    func testGreatCirclePrecisionAndDateline() {
        XCTAssertEqual(FlightMetrics.distance(jfk, lhr), 5540, accuracy: 12)
        XCTAssertEqual(FlightMetrics.distance(jfk, nrt), 10830, accuracy: 30)
        XCTAssertEqual(FlightMetrics.distance(jfk, lhr), FlightMetrics.distance(lhr, jfk), accuracy: 0.000001)
        XCTAssertEqual(FlightMetrics.distance(jfk, jfk), 0)
        XCTAssertEqual(FlightMetrics.distance(airport("A", 0, 179), airport("B", 0, -179)), 222.39, accuracy: 0.1)
        XCTAssertEqual(FlightMetrics.distance(airport("A", 0, 0), airport("B", 0, 180)), Double.pi * FlightMetrics.earthRadiusKM, accuracy: 0.001)
    }
    func testStatisticsTiesSingleEmptyAndFullPrecision() throws {
        let a = try flight(jfk, lhr), b = try flight(lhr, jfk), c = try flight(nrt, jfk)
        let stats = Statistics([a,b,c])
        XCTAssertEqual(stats.airportCount, 3); XCTAssertEqual(stats.shortest.count, 2)
        XCTAssertEqual(stats.longest.map(\.id), [c.id]); XCTAssertEqual(stats.routes.count, 2)
        XCTAssertEqual(stats.frequentRoutes.first?.count, 2)
        XCTAssertEqual(stats.months[4], 3)
        XCTAssertEqual(Statistics([a]).shortest, Statistics([a]).longest)
        XCTAssertTrue(Statistics([]).shortest.isEmpty); XCTAssertEqual(Statistics([]).minutes, 0)
        let near = airport("NEAR", lhr.latitude + 0.00001, lhr.longitude)
        let d = try flight(jfk, near)
        XCTAssertEqual(Statistics([a,d]).shortest.count, 1, "Display rounding must not create ties")
    }
    func testInclusiveRangesAndDuplicates() throws {
        let a = try flight(jfk, lhr), b = try flight(jfk, lhr), reverse = try flight(lhr, jfk)
        XCTAssertTrue(a.likelyDuplicate(of: b)); XCTAssertFalse(a.likelyDuplicate(of: a)); XCTAssertFalse(a.likelyDuplicate(of: reverse))
        XCTAssertTrue(DateRange.custom(a.departure, a.departure).includes(a.departure))
        XCTAssertFalse(DateRange.year(2025).includes(a.departure))
        XCTAssertTrue(DateRange.all.includes(a.departure))
    }
    func testEstimateSanityAndComparableBasis() throws {
        let distances = [0.0, 50, 200, 500, 1000, 5500, 11000, 20000]
        let minutes = distances.map(FlightMetrics.estimatedMinutes)
        XCTAssertEqual(minutes, minutes.sorted()); XCTAssertEqual(minutes.first, 15)
        XCTAssertEqual(FlightMetrics.estimatedMinutes(km: 5500), 430)
        var f = try flight(jfk, lhr)
        f.measurements.append(Measurement(value: 600, unit: "minutes", basis: .gateToGate, kind: .observed, provider: "test", version: "1"))
        XCTAssertEqual(f.duration.kind, .estimated)
        let correction = Measurement(value: 390, unit: "minutes", basis: .airborne, kind: .userSupplied, provider: "User", version: "1")
        f.corrections.append(correction); XCTAssertEqual(f.duration, correction)
        XCTAssertEqual(Statistics([f]).estimatedCount, 0)
        try f.validate()
    }
    func testFlightRoundTripPreservesOriginalFactsAndProvenance() throws {
        var f = try flight(nrt, jfk, "1998-01-02")
        f.notes = "A memory, with \"quotes\"\nand a new line"; f.airline = "Example"; f.flightNumber = "AB12"
        let restored = try JSONDecoder().decode(Flight.self, from: JSONEncoder().encode(f))
        XCTAssertEqual(restored, f); XCTAssertEqual(restored.id, f.id)
        XCTAssertEqual(restored.origin.sourceVersion, "test"); XCTAssertEqual(restored.departure.description, "1998-01-02")
        XCTAssertEqual(restored.duration.version, FlightMetrics.durationVersion)
    }
    func testInvalidFlightAndMeasurementRejected() throws {
        XCTAssertThrowsError(try flight(jfk, jfk).validate())
        var invalid = jfk; invalid.latitude = .nan
        XCTAssertThrowsError(try invalid.validate())
        let m = Measurement(value: -2, unit: "minutes", basis: .airborne, kind: .estimated, provider: "test", version: "1")
        XCTAssertThrowsError(try m.validate())
    }
}
