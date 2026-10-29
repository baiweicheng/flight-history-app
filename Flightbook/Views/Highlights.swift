import SwiftUI

struct Highlights: View {
    let stats: Statistics
    let unit: DistanceUnit
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Flight highlights").font(.title3.weight(.semibold))
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) { cards }
                VStack(spacing: 12) { cards }
            }
        }
    }
    @ViewBuilder private var cards: some View {
        card("Shortest flight", flights: stats.shortest, icon: "arrow.down.right")
        card("Longest flight", flights: stats.longest, icon: "arrow.up.right")
    }
    private func card(_ title: String, flights: [Flight], icon: String) -> some View {
        NavigationLink {
            FlightDrilldown(title: title + (flights.count > 1 ? "s · tied" : ""), ids: Set(flights.map(\.id)), unit: unit)
        } label: {
            if let flight = flights.first {
                VStack(alignment: .leading, spacing: 10) {
                    Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
                    Text(flight.routeLabel).font(.headline).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
                    Text(unit.format(flight.distanceKM)).font(.subheadline.weight(.medium)).foregroundStyle(Palette.accent)
                    Text(flights.count > 1 ? "\(flights.count) tied flights" : flight.departure.formatted).font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 110, alignment: .leading).surface()
            }
        }.buttonStyle(.plain)
    }
}

struct FrequentRoutes: View {
    let stats: Statistics
    let unit: DistanceUnit
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most frequent routes").font(.title3.weight(.semibold))
            ForEach(stats.frequentRoutes) { group in
                NavigationLink {
                    FlightDrilldown(title: group.label, ids: Set(group.flights.map(\.id)), unit: unit)
                } label: {
                    HStack {
                        Text(group.label).font(.headline)
                        Spacer()
                        Text("\(group.count) \(group.count == 1 ? "flight" : "flights")").foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption)
                    }.padding(.vertical, 12).frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
    }
}

struct FlightDrilldown: View {
    @Environment(FlightStore.self) private var store
    let title: String
    let ids: Set<UUID>
    let unit: DistanceUnit
    var body: some View {
        List {
            let flights = store.flights.filter { ids.contains($0.id) }
            if flights.isEmpty { ContentUnavailableView("No flights remain", systemImage: "airplane") }
            ForEach(flights) { flight in
                NavigationLink { FlightDetail(id: flight.id, unit: unit) } label: { FlightRow(flight: flight, unit: unit) }
            }
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}
