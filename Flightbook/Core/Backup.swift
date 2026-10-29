import Foundation
import CryptoKit

public struct FlightBackup: Codable, Sendable, Identifiable {
    public var format: String
    public var schemaVersion: Int
    public var appVersion: String
    public var exportedAt: Date
    public var flights: [Flight]
    public var checksum: String
    public var id: String { checksum + String(exportedAt.timeIntervalSince1970) }
}

public enum BackupCodec {
    public static let maximumBytes = 32 * 1024 * 1024
    private struct Header: Decodable { var format: String; var schemaVersion: Int }
    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return encoder
    }
    private static func digest(_ flights: [Flight]) throws -> String {
        SHA256.hash(data: try encoder().encode(flights)).map { String(format: "%02x", $0) }.joined()
    }
    public static func make(_ flights: [Flight], at: Date = .now) throws -> FlightBackup {
        try validate(flights)
        guard validTimestamp(at) else { throw FlightError.invalidBackup }
        return FlightBackup(format: "flightbook", schemaVersion: 1, appVersion: "1.0", exportedAt: at,
                            flights: flights, checksum: try digest(flights))
    }
    public static func encode(_ flights: [Flight], at: Date = .now) throws -> Data {
        let data = try encoder().encode(make(flights, at: at))
        guard data.count <= maximumBytes else { throw FlightError.invalidBackup }; return data
    }
    public static func decode(_ data: Data) throws -> FlightBackup {
        guard data.count <= maximumBytes else { throw FlightError.invalidBackup }
        do {
            let header = try JSONDecoder().decode(Header.self, from: data)
            guard header.format == "flightbook" else { throw FlightError.invalidBackup }
            guard header.schemaVersion == 1 else { throw FlightError.unsupportedVersion }
            let backup = try JSONDecoder().decode(FlightBackup.self, from: data)
            try validate(backup.flights)
            guard validTimestamp(backup.exportedAt), backup.checksum == (try digest(backup.flights)) else { throw FlightError.invalidBackup }
            return backup
        } catch let error as FlightError { throw error }
        catch { throw FlightError.invalidBackup }
    }
    private static func validate(_ flights: [Flight]) throws {
        guard Set(flights.map(\.id)).count == flights.count else { throw FlightError.invalidBackup }
        for flight in flights { try flight.validate() }
    }
}

public enum RestoreMode: String, CaseIterable, Sendable { case merge = "Merge", replace = "Replace" }
public struct RestorePlan: Sendable {
    public var resultingFlights: [Flight]
    public var added: Int
    public var unchanged: Int
    public var conflicts: Int
    public var possibleDuplicates: Int
    public init(existing: [Flight], incoming: [Flight], mode: RestoreMode) {
        let local = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        added = 0; unchanged = 0; conflicts = 0; possibleDuplicates = 0
        var result = existing
        for flight in incoming {
            if let previous = local[flight.id] {
                if previous == flight { unchanged += 1 } else { conflicts += 1 }
            } else {
                added += 1
                if existing.contains(where: { $0.likelyDuplicate(of: flight) }) { possibleDuplicates += 1 }
                result.append(flight)
            }
        }
        resultingFlights = FlightMetrics.sorted(mode == .replace ? incoming : result)
    }
}

public enum CSVExport {
    /// Every field is quoted. Prefix spreadsheet formula triggers so user text opens as text in spreadsheets.
    /// Lossless restoration uses JSON backups; CSV is a portable, human-readable export.
    public static func encode(_ flights: [Flight]) -> String {
        let header = ["id","departure_local_date","origin_code","origin_name","origin_id","origin_latitude","origin_longitude",
                      "destination_code","destination_name","destination_id","destination_latitude","destination_longitude",
                      "airline","flight_number","notes","route_km","airborne_minutes","duration_evidence","duration_basis","duration_model","duration_version"]
        func quote(_ s: String, sanitize: Bool = false) -> String {
            let leading = s.drop(while: { $0.isWhitespace }).first
            let trigger = leading.map { "=+-@".contains($0) } == true || s.first == "\t" || s.first == "\r"
            let safe = sanitize && trigger ? "'" + s : s
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let rows = FlightMetrics.sorted(flights).map { f in
            [f.id.uuidString, f.departure.description, f.origin.code, f.origin.name, f.origin.id, String(f.origin.latitude), String(f.origin.longitude),
             f.destination.code, f.destination.name, f.destination.id, String(f.destination.latitude), String(f.destination.longitude),
             f.airline ?? "", f.flightNumber ?? "", f.notes ?? "", String(f.distanceKM), String(f.duration.value),
             f.duration.kind.rawValue, f.duration.basis.rawValue, f.duration.provider, f.duration.version]
        }
        let textColumns: Set<Int> = [2,3,4,7,8,9,12,13,14,17,18,19,20]
        let lines = [header.map { quote($0) }.joined(separator: ",")] + rows.map { row in
            row.enumerated().map { quote($0.element, sanitize: textColumns.contains($0.offset)) }.joined(separator: ",")
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }
}
