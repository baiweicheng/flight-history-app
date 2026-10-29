import Foundation

public enum FlightMetrics {
    public static let earthRadiusKM = 6371.0088
    public static let durationVersion = "airborne-heuristic-1"
    public static func distance(_ a: Airport, _ b: Airport) -> Double {
        let radians = Double.pi / 180
        let p1 = a.latitude * radians, p2 = b.latitude * radians
        let dp = (b.latitude - a.latitude) * radians, dl = (b.longitude - a.longitude) * radians
        let h = pow(sin(dp / 2), 2) + cos(p1) * cos(p2) * pow(sin(dl / 2), 2)
        return earthRadiusKM * 2 * atan2(sqrt(min(1, max(0, h))), sqrt(max(0, 1 - h)))
    }
    /// Transparent planning estimate, not a historical observation. Cruise plus airborne climb/descent allowance.
    /// Rounded to five minutes; excludes taxi, layovers, wind and aircraft-specific performance.
    public static func estimatedMinutes(km: Double) -> Double {
        let speed = 450 + 350 * min(1, max(0, km) / 1000)
        return max(15, ((max(0, km) / speed * 60 + 15) / 5).rounded() * 5)
    }
    public static func measurements(origin: Airport, destination: Airport, at: Date) -> [Measurement] {
        let km = distance(origin, destination)
        return [
            Measurement(value: km, unit: "km", basis: .airportToAirport, kind: .calculated,
                        provider: "Great-circle / mean Earth radius", version: "haversine-1", at: at),
            Measurement(value: estimatedMinutes(km: km), unit: "minutes", basis: .airborne, kind: .estimated,
                        provider: "Flightbook airborne heuristic", version: durationVersion, at: at)
        ]
    }
    public static func sorted(_ flights: [Flight]) -> [Flight] {
        flights.sorted { $0.departure == $1.departure ? $0.id.uuidString < $1.id.uuidString : $0.departure > $1.departure }
    }
}

public enum DateRange: Hashable, Sendable {
    case all, year(Int), custom(LocalDate, LocalDate)
    public func includes(_ date: LocalDate) -> Bool {
        switch self {
        case .all: true
        case .year(let year): date.year == year
        case .custom(let start, let end): date >= start && date <= end
        }
    }
    public var label: String {
        switch self {
        case .all: "All time"
        case .year(let year): String(year)
        case .custom(let start, let end): "\(start.formatted) – \(end.formatted)"
        }
    }
}

public struct RouteGroup: Identifiable, Sendable {
    public var id: String
    public var flights: [Flight]
    public var label: String { [flights[0].origin.code, flights[0].destination.code].sorted().joined(separator: " ↔ ") }
    public var count: Int { flights.count }
    public static func groups(_ flights: [Flight]) -> [RouteGroup] {
        Dictionary(grouping: flights, by: \.routeKey).map { RouteGroup(id: $0.key, flights: FlightMetrics.sorted($0.value)) }
            .sorted { $0.count == $1.count ? $0.label < $1.label : $0.count > $1.count }
    }
}

public struct Statistics: Sendable {
    public var flights: [Flight]
    public init(_ flights: [Flight]) { self.flights = FlightMetrics.sorted(flights) }
    public var distanceKM: Double { flights.reduce(0) { $0 + $1.distanceKM } }
    public var minutes: Double { flights.reduce(0) { $0 + $1.duration.value } }
    public var estimatedCount: Int { flights.filter { $0.duration.kind == .estimated }.count }
    public var airportCount: Int { Set(flights.flatMap { [$0.origin.id, $0.destination.id] }).count }
    public var shortest: [Flight] { extremes(longest: false) }
    public var longest: [Flight] { extremes(longest: true) }
    public var routes: [RouteGroup] { RouteGroup.groups(flights) }
    public var frequentRoutes: [RouteGroup] { routes.filter { $0.count == routes.first?.count } }
    public var months: [Int] { (1...12).map { m in flights.filter { $0.departure.month == m }.count } }
    private func extremes(longest: Bool) -> [Flight] {
        guard let km = (longest ? flights.map(\.distanceKM).max() : flights.map(\.distanceKM).min()) else { return [] }
        return flights.filter { abs($0.distanceKM - km) < 0.000001 }
    }
}

public enum DistanceUnit: String, CaseIterable, Sendable {
    case miles = "Miles", kilometers = "Kilometers"
    public var symbol: String { self == .miles ? "mi" : "km" }
    public func value(_ km: Double) -> Double { self == .miles ? km / 1.609344 : km }
    public func format(_ km: Double) -> String { "\(value(km).formatted(.number.precision(.fractionLength(0)))) \(symbol)" }
}
public func durationText(_ minutes: Double) -> String {
    let m = Int(minutes.rounded())
    return m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h \(m % 60)m"
}
