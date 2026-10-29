import Foundation

actor AirportCatalog {
    static let shared = AirportCatalog()
    private var entries: [(Airport, String)] = []
    private var loaded = false
    func search(_ query: String) throws -> [Airport] {
        if !loaded {
            guard let url = Bundle.main.url(forResource: "airports", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let airports = try JSONDecoder().decode([Airport].self, from: Data(contentsOf: url))
            entries = airports.map { ($0, $0.searchText) }; loaded = true
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).folded
        let tokens = q.split(separator: " ").map(String.init)
        if q.isEmpty { return Array(entries.filter { $0.0.kind == "large_airport" }.prefix(30).map(\.0)) }
        return Array(entries.lazy.filter { entry in tokens.allSatisfy { entry.1.contains($0) } }
            .sorted { a, b in
                func rank(_ a: Airport) -> Int {
                    if a.code.folded == q || a.ident.folded == q { return 0 }
                    if a.code.folded.hasPrefix(q) { return 1 }
                    if a.kind == "large_airport" { return 2 }
                    return a.isClosed ? 4 : 3
                }
                let ra = rank(a.0), rb = rank(b.0)
                return ra == rb ? a.0.name < b.0.name : ra < rb
            }.prefix(60).map(\.0))
    }
}
