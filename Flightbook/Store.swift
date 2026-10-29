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

    init(inMemory: Bool = false) throws {
        let schema = Schema(versionedSchema: FlightbookSchemaV1.self)
        let isTesting = ProcessInfo.processInfo.arguments.contains("-uitesting")
        let config = ModelConfiguration(isTesting ? "Flightbook-UAT" : "Flightbook", schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
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
    private func records() throws -> [FlightRecord] { try container.mainContext.fetch(FetchDescriptor<FlightRecord>()) }
    private func transaction(_ changes: () throws -> Void) throws {
        do { try changes(); try container.mainContext.save(); try reload() }
        catch { container.mainContext.rollback(); throw error }
    }
}
