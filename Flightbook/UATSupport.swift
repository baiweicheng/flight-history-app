#if DEBUG
import Foundation

/// Deterministic fixtures are available only in debug builds and the separate UAT store.
@MainActor enum UATSupport {
    static func seed(_ store: FlightStore) throws {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uitesting"), args.contains("-seed-uat"), store.flights.isEmpty else { return }
        let url = Bundle.main.url(forResource: "airports", withExtension: "json")!
        let airports = try JSONDecoder().decode([Airport].self, from: Data(contentsOf: url))
        func airport(_ code: String) -> Airport { airports.first { $0.iata == code && $0.kind == "large_airport" }! }
        let fixtures = [("JFK","LHR","2026-05-13"),("LHR","FCO","2026-05-15"),("FCO","LHR","2026-05-23"),("LHR","JFK","2026-05-23"),
                        ("JFK","SFO","2026-09-04"),("SFO","JFK","2026-09-10"),("JFK","NRT","2025-11-12"),("NRT","JFK","2025-11-26")]
        for (i, entry) in fixtures.enumerated() {
            let flight = Flight(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i+1))!,
                                origin: airport(entry.0), destination: airport(entry.1), departure: try LocalDate(iso: entry.2), notes: "UAT fixture — illustrative, not personal history")
            try store.save(flight)
        }
    }
}
#endif
