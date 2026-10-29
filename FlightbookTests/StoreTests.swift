import XCTest
import SwiftData
@testable import Flightbook

@MainActor final class StoreTests: XCTestCase {
    func fixture() throws -> Flight {
        let a = Airport(id: "1", ident: "KJFK", iata: "JFK", name: "John F. Kennedy", city: "New York", country: "US", latitude: 40.64, longitude: -73.77, kind: "large_airport", sourceVersion: "test")
        var b = a; b.id = "2"; b.ident = "EGLL"; b.iata = "LHR"; b.longitude = -0.45; b.latitude = 51.47
        return Flight(origin: a, destination: b, departure: try LocalDate(iso: "2026-05-13"))
    }
    func testVersionedStoreReopensOnDisk() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "test.sqlite")
        var first: FlightStore? = try FlightStore(storeURL: url)
        let f = try fixture(); try first?.save(f); first = nil
        let reopened = try FlightStore(storeURL: url)
        XCTAssertEqual(reopened.flights, [f])
    }
    func testRestoreMergeReplaceAndRecoveryAreLossless() throws {
        let recovery = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: recovery) }
        let store = try FlightStore(inMemory: true, recoveryURL: recovery)
        let f = try fixture(); try store.save(f)
        var revised = f; revised.notes = "Backup version"
        var other = f; other.id = UUID(); other.departure = try LocalDate(iso: "2025-01-01")
        let backup = try BackupCodec.make([revised, other])
        try store.restore(backup, mode: .merge)
        XCTAssertEqual(store.flights.count, 2); XCTAssertNil(store.flights.first { $0.id == f.id }?.notes)
        XCTAssertEqual(try store.recoveryBackup().flights, [f])
        try store.restore(backup, mode: .replace)
        XCTAssertEqual(store.flights.first { $0.id == f.id }?.notes, "Backup version")
        let previous = try store.recoveryBackup()
        try store.restore(previous, mode: .replace)
        XCTAssertNil(store.flights.first { $0.id == f.id }?.notes)
        try store.reload(); XCTAssertEqual(store.flights.count, 2)
    }
    func testRecoveryFailureLeavesTheDatabaseUntouched() throws {
        let blocker = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data("file".utf8).write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        let store = try FlightStore(inMemory: true, recoveryURL: blocker.appending(path: "recovery.json"))
        let f = try fixture(); try store.save(f)
        XCTAssertThrowsError(try store.restore(BackupCodec.make([]), mode: .replace))
        try store.reload(); XCTAssertEqual(store.flights, [f])
    }
    func testAirportSearchIsOfflineAndSupportsHistoricalAirports() async throws {
        let code = try await AirportCatalog.shared.search("JFK")
        XCTAssertEqual(code.first?.iata, "JFK")
        let city = try await AirportCatalog.shared.search("London Heathrow")
        XCTAssertEqual(city.first?.iata, "LHR")
        let historical = try await AirportCatalog.shared.search("Kai Tak")
        XCTAssertTrue(historical.contains { $0.isClosed })
        let absent = try await AirportCatalog.shared.search("zzzzzzzzzzzzzzz")
        XCTAssertTrue(absent.isEmpty)
    }
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
