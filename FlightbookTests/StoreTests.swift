import XCTest
import SwiftData
@testable import Flightbook

@MainActor final class StoreTests: XCTestCase {
    func testInsertEditDeleteAndUndoArePersistentAndKeepIdentity() throws {
        let store = try FlightStore(inMemory: true)
        let a = Airport(id: "1", ident: "KJFK", iata: "JFK", name: "John F. Kennedy", city: "New York", country: "US", latitude: 40.64, longitude: -73.77, kind: "large_airport", sourceVersion: "test")
        var b = a; b.id = "2"; b.ident = "EGLL"; b.iata = "LHR"; b.longitude = -0.45; b.latitude = 51.47
        var f = Flight(origin: a, destination: b, departure: try LocalDate(iso: "2026-05-13"))
        try store.save(f); try store.reload(); XCTAssertEqual(store.flights, [f])
        f.notes = "Edited"; try store.save(f); try store.reload()
        XCTAssertEqual(store.flights.count, 1); XCTAssertEqual(store.flights[0].id, f.id); XCTAssertEqual(store.flights[0].notes, "Edited")
        try store.delete(f); XCTAssertTrue(store.flights.isEmpty)
        try store.undoDelete(); XCTAssertEqual(store.flights, [f])
        try store.undoDelete(); XCTAssertEqual(store.flights.count, 1)
    }
}
