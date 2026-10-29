import Foundation

public enum FlightCalendar {
    public static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!; calendar.locale = .current
        return calendar
    }
    public static var current: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current; calendar.locale = .current
        return calendar
    }
}

func validTimestamp(_ date: Date) -> Bool {
    let seconds = date.timeIntervalSince1970
    return seconds.isFinite && (-62_135_596_800...253_402_300_799).contains(seconds)
}

/// The departure airport's calendar date, independent of UTC or the device's time zone.
public struct LocalDate: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard (1...9999).contains(year), let date = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day], from: date).year == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { throw FlightError.invalidDate }
        self.year = year; self.month = month; self.day = day
    }

    public init(_ date: Date, calendar: Calendar = FlightCalendar.current) {
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
        day = calendar.component(.day, from: date)
    }

    public init(iso: String) throws {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { throw FlightError.invalidDate }
        try self.init(year: y, month: m, day: d)
    }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.description < rhs.description }
    public var pickerDate: Date {
        FlightCalendar.utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    public var formatted: String {
        pickerDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: FlightCalendar.utc, timeZone: TimeZone(secondsFromGMT: 0)!))
    }
    public init(from decoder: Decoder) throws { try self.init(iso: decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(description) }
}

public enum FlightError: LocalizedError, Equatable {
    case invalidDate, invalidAirport, sameAirport, invalidMeasurement, unsupportedVersion, invalidBackup
    public var errorDescription: String? {
        switch self {
        case .invalidDate: "Choose a valid local departure date."
        case .invalidAirport: "An airport has missing or invalid coordinates."
        case .sameAirport: "Choose different departure and arrival airports."
        case .invalidMeasurement: "The flight contains an invalid measurement."
        case .unsupportedVersion: "This backup was created by a newer version of Flightbook. Update the app before restoring it."
        case .invalidBackup: "This file is not a valid Flightbook backup. Your log has not changed."
        }
    }
}

public struct Airport: Codable, Hashable, Identifiable, Sendable {
    /// Stable OurAirports numeric ID, never an IATA code that can be reassigned.
    public var id: String
    public var ident: String
    public var iata: String?
    public var name: String
    public var city: String
    public var country: String
    public var latitude: Double
    public var longitude: Double
    public var kind: String
    public var sourceVersion: String
    public var code: String { iata.flatMap { $0.isEmpty ? nil : $0 } ?? ident }
    public var isClosed: Bool { kind.contains("closed") }
    public var searchText: String { "\(code) \(ident) \(city) \(name) \(country)".folded }
    public func validate() throws {
        guard !id.isEmpty, !ident.isEmpty, !name.isEmpty, latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { throw FlightError.invalidAirport }
    }
}

extension String {
    public var folded: String { folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
}

public struct Measurement: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case estimated, calculated, scheduled, observed, userSupplied }
    public enum Basis: String, Codable, Sendable { case airborne, gateToGate, airportToAirport, aircraftTrack }
    public var id: UUID
    public var value: Double
    public var unit: String
    public var basis: Basis
    public var kind: Kind
    public var provider: String
    public var version: String
    public var calculatedAt: Date
    public var providerFlightID: String?

    public init(value: Double, unit: String, basis: Basis, kind: Kind, provider: String, version: String, at: Date = .now) {
        id = UUID(); self.value = value; self.unit = unit; self.basis = basis; self.kind = kind
        self.provider = provider; self.version = version; calculatedAt = at
    }
    public func validate() throws {
        guard value.isFinite, value >= 0, value <= (unit == "minutes" ? 10_080 : 100_000_000), !provider.isEmpty, !version.isEmpty,
              ["km", "minutes"].contains(unit), validTimestamp(calculatedAt),
              (unit == "km" ? [.airportToAirport, .aircraftTrack].contains(basis) : [.airborne, .gateToGate].contains(basis))
        else { throw FlightError.invalidMeasurement }
    }
}

public struct MetricRevision: Codable, Hashable, Sendable {
    public var origin: Airport
    public var destination: Airport
    public var archivedAt: Date
    public var measurements: [Measurement]
    public var corrections: [Measurement]
}

public struct Flight: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var origin: Airport
    public var destination: Airport
    public var departure: LocalDate
    public var airline: String?
    public var flightNumber: String?
    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var measurements: [Measurement]
    public var corrections: [Measurement]
    public var metricHistory: [MetricRevision]?

    public init(id: UUID = UUID(), origin: Airport, destination: Airport, departure: LocalDate,
                airline: String? = nil, flightNumber: String? = nil, notes: String? = nil, now: Date = .now) {
        self.id = id; self.origin = origin; self.destination = destination; self.departure = departure
        self.airline = airline; self.flightNumber = flightNumber; self.notes = notes
        createdAt = now; updatedAt = now; corrections = []
        measurements = FlightMetrics.measurements(origin: origin, destination: destination, at: now)
    }
    public var distanceKM: Double { FlightMetrics.distance(origin, destination) }
    public var duration: Measurement {
        corrections.last(where: { $0.basis == .airborne && $0.unit == "minutes" })
        ?? measurements.last(where: { $0.basis == .airborne && $0.unit == "minutes" })
        ?? FlightMetrics.measurements(origin: origin, destination: destination, at: updatedAt)[1]
    }
    public var routeKey: String { [origin.id, destination.id].sorted().joined(separator: ":") }
    public var durationLabel: String {
        switch duration.kind {
        case .estimated: "Estimated airborne time"
        case .userSupplied: "Your airborne time"
        case .observed: "Observed airborne time"
        case .scheduled: "Scheduled airborne time"
        case .calculated: "Calculated airborne time"
        }
    }
    public var routeLabel: String { "\(origin.code) → \(destination.code)" }
    public func validate() throws {
        try origin.validate(); try destination.validate()
        guard origin.id != destination.id else { throw FlightError.sameAirport }
        guard validTimestamp(createdAt), validTimestamp(updatedAt) else { throw FlightError.invalidBackup }
        for value in measurements + corrections { try value.validate() }
        for revision in metricHistory ?? [] {
            try revision.origin.validate(); try revision.destination.validate()
            guard validTimestamp(revision.archivedAt) else { throw FlightError.invalidBackup }
            for value in revision.measurements + revision.corrections { try value.validate() }
        }
        guard Set((measurements + corrections).map(\.id)).count == measurements.count + corrections.count else { throw FlightError.invalidBackup }
    }
    public mutating func reviseRoute(origin: Airport, destination: Airport, at: Date = .now) {
        guard self.origin.id != origin.id || self.destination.id != destination.id else { return }
        let revision = MetricRevision(origin: self.origin, destination: self.destination, archivedAt: at, measurements: measurements, corrections: corrections)
        metricHistory = (metricHistory ?? []) + [revision]
        measurements = FlightMetrics.measurements(origin: origin, destination: destination, at: at)
        corrections = []; self.origin = origin; self.destination = destination; updatedAt = at
    }
    public func likelyDuplicate(of other: Flight) -> Bool {
        id != other.id && origin.id == other.origin.id && destination.id == other.destination.id && departure == other.departure
    }
    public var searchText: String {
        "\(origin.searchText) \(destination.searchText) \(airline ?? "") \(flightNumber ?? "") \(notes ?? "")".folded
    }
}
