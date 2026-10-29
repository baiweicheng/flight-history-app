import Foundation
import Observation
import SwiftData

enum FlightbookSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [FlightRecord.self] }
    @Model final class FlightRecord {
        @Attribute(.unique) var id: UUID
        var payload: Data
        init(_ flight: Flight) throws { id = flight.id; payload = try JSONEncoder().encode(flight) }
    }
}
enum FlightbookMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [FlightbookSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
typealias FlightRecord = FlightbookSchemaV1.FlightRecord

@MainActor @Observable final class FlightStore {
    let container: ModelContainer
    private(set) var flights: [Flight] = []
    var error: String?
    private(set) var deleted: Flight?
    let recoveryURL: URL

    init(inMemory: Bool = false, storeURL: URL? = nil, recoveryURL: URL? = nil) throws {
        let schema = Schema(versionedSchema: FlightbookSchemaV1.self)
        let isTesting = ProcessInfo.processInfo.arguments.contains("-uitesting")
        let name = isTesting ? "Flightbook-UAT" : "Flightbook"
        let config = storeURL.map { ModelConfiguration(name, schema: schema, url: $0, cloudKitDatabase: .none) }
            ?? ModelConfiguration(name, schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        self.recoveryURL = recoveryURL ?? URL.applicationSupportDirectory.appending(path: name + "-Recovery.json")
        container = try ModelContainer(for: schema, migrationPlan: FlightbookMigrationPlan.self, configurations: [config])
        container.mainContext.autosaveEnabled = false
        if isTesting && ProcessInfo.processInfo.arguments.contains("-reset-test-data") {
            try container.mainContext.delete(model: FlightRecord.self)
            try container.mainContext.save()
        }
        try reload()
    }
    func reload() throws {
        let decoded = try container.mainContext.fetch(FetchDescriptor<FlightRecord>()).map { record in
            let flight = try JSONDecoder().decode(Flight.self, from: record.payload)
            try flight.validate()
            guard flight.id == record.id else { throw FlightError.invalidBackup }
            return flight
        }
        flights = FlightMetrics.sorted(decoded)
    }
    func save(_ flight: Flight) throws {
        try flight.validate()
        try transaction {
            if let record = try records().first(where: { $0.id == flight.id }) {
                record.payload = try JSONEncoder().encode(flight)
            } else { container.mainContext.insert(try FlightRecord(flight)) }
        }
    }
    func delete(_ flight: Flight) throws {
        try transaction {
            if let record = try records().first(where: { $0.id == flight.id }) { container.mainContext.delete(record) }
        }
        deleted = flight
    }
    func undoDelete() throws {
        guard let deleted else { return }
        try save(deleted); self.deleted = nil
    }
    func dismissUndo() { deleted = nil }
    func restore(_ backup: FlightBackup, mode: RestoreMode) throws {
        // Validate everything before touching either the recovery copy or the database.
        _ = try BackupCodec.encode(backup.flights)
        let plan = RestorePlan(existing: flights, incoming: backup.flights, mode: mode)
        let previous = try BackupCodec.encode(flights)
        try FileManager.default.createDirectory(at: recoveryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try previous.write(to: recoveryURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        try transaction {
            let old = try records()
            let retained = Set(plan.resultingFlights.map(\.id))
            for record in old where !retained.contains(record.id) { container.mainContext.delete(record) }
            let byID = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
            for flight in plan.resultingFlights {
                if let record = byID[flight.id] { record.payload = try JSONEncoder().encode(flight) }
                else { container.mainContext.insert(try FlightRecord(flight)) }
            }
        }
        deleted = nil
    }
    func recoveryBackup() throws -> FlightBackup { try BackupCodec.decode(Data(contentsOf: recoveryURL)) }
    var hasRecovery: Bool { FileManager.default.fileExists(atPath: recoveryURL.path) }
    private func records() throws -> [FlightRecord] { try container.mainContext.fetch(FetchDescriptor<FlightRecord>()) }
    private func transaction(_ changes: () throws -> Void) throws {
        do { try changes(); try container.mainContext.save(); try reload() }
        catch { container.mainContext.rollback(); throw error }
    }
}
