import SwiftUI
import Charts

struct AnnualView: View {
    @Environment(FlightStore.self) private var store
    @Binding var year: Int
    let years: [Int]
    let unit: DistanceUnit
    let add: () -> Void
    @State private var map = RouteMapState()
    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    private var flights: [Flight] { store.flights.filter { $0.departure.year == year } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(title: "Annual summary", subtitle: "A look back, one year at a time.")
                HStack {
                    Menu {
                        ForEach(years, id: \.self) { value in Button(String(value)) { year = value } }
                    } label: {
                        Label(String(year), systemImage: "calendar").font(.headline).padding(.horizontal, 16).frame(minHeight: 44)
                            .background(Palette.surface, in: Capsule())
                    }.accessibilityLabel("Summary year, \(String(year))").accessibilityIdentifier("annualYear")
                    Spacer()
                    Text(year == currentYear ? "Year in progress" : "Year in review").font(.caption).foregroundStyle(.secondary)
                }
                Text(year == currentYear ? "Your year, so far" : "A year of journeys").font(.title2.weight(.medium))
                if flights.isEmpty {
                    ContentUnavailableView {
                        Label("A new chapter awaits", systemImage: "calendar.badge.plus")
                    } description: { Text("No flights logged for \(String(year)) yet.") }
                    actions: { Button("Add a past flight", action: add).buttonStyle(.borderedProminent) }
                } else {
                    let stats = Statistics(flights)
                    MetricsCard(stats: stats, unit: unit)
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Flights by month").font(.title3.weight(.semibold))
                        Chart(Array(stats.months.enumerated()), id: \.offset) { index, count in
                            BarMark(x: .value("Month", index+1), y: .value("Flights", count))
                                .foregroundStyle(Palette.accent).cornerRadius(4)
                                .annotation(position: .top) { if count > 0 { Text(String(count)).font(.caption2) } }
                                .accessibilityLabel(Calendar.current.monthSymbols[index])
                                .accessibilityValue("\(count) flights")
                        }.chartXScale(domain: 0.5...12.5)
                            .chartXAxis { AxisMarks(values: [1,4,7,10,12]) { value in
                                if let month = value.as(Int.self) { AxisValueLabel(Calendar.current.shortMonthSymbols[month-1]) }
                            } }
                            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) { value in
                                if let count = value.as(Int.self) { AxisGridLine(); AxisValueLabel(String(count)) }
                            } }
                            .frame(height: 160)
                    }.surface()
                    Highlights(stats: stats, unit: unit)
                    FrequentRoutes(stats: stats, unit: unit)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("\(String(year)) route map").font(.title3.weight(.semibold))
                        RouteMap(flights: flights, state: map, interactive: false).frame(height: 250)
                        Text("\(stats.routes.count) routes · \(stats.airportCount) airports").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("\(stats.estimatedCount) of \(flights.count) flights use estimated airborne time. This summary updates as you add past flights.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(24)
        }.background(Palette.background)
            .onChange(of: year) { _, _ in map.initialized = false }
    }
}
