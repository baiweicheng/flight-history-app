import SwiftUI

struct FlightDetail: View {
    @Environment(FlightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    let unit: DistanceUnit
    @State private var editing = false
    @State private var returning = false
    @State private var deleting = false
    @State private var map = RouteMapState()
    var body: some View {
        Group {
            if let flight = store.flights.first(where: { $0.id == id }) {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(flight.departure.formatted).font(.subheadline).foregroundStyle(.secondary)
                            Text(flight.routeLabel).font(.largeTitle.weight(.medium))
                            Text("\(flight.origin.name) to \(flight.destination.name)").font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical)
                    }
                    Section { RouteMap(flights: [flight], state: map, interactive: false).frame(height: 225).listRowInsets(EdgeInsets()) }
                    Section {
                        LabeledContent("Route distance", value: unit.format(flight.distanceKM))
                        LabeledContent(flight.durationLabel, value: (flight.duration.kind == .estimated ? "~ " : "") + durationText(flight.duration.value))
                        LabeledContent("Departure date", value: flight.departure.formatted)
                        if let airline = flight.airline { LabeledContent("Airline", value: airline) }
                        if let number = flight.flightNumber { LabeledContent("Flight", value: number) }
                    } footer: { Text("Great-circle airport distance. Airborne time excludes taxi and layovers.\nSource: \(flight.duration.provider), \(flight.duration.version). \(flight.duration.kind == .estimated ? "This is a planning estimate. " : "")Departure is a local calendar date.") }
                    if let notes = flight.notes { Section("Notes") { Text(notes) } }
                    Section {
                        Button("Add return flight", systemImage: "arrow.uturn.backward") { returning = true }.frame(minHeight: 44)
                        Button("Delete flight", systemImage: "trash", role: .destructive) { deleting = true }.frame(minHeight: 44)
                    }
                }.navigationTitle("Flight details").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } } }
                    .sheet(isPresented: $editing) { FlightForm(existing: flight) }
                    .sheet(isPresented: $returning) { FlightForm(returnFrom: flight) }
                    .confirmationDialog("Delete this flight?", isPresented: $deleting, titleVisibility: .visible) {
                        Button("Delete flight", role: .destructive) {
                            do { try store.delete(flight); dismiss() } catch { store.error = error.localizedDescription }
                        }
                    } message: { Text("You can undo this after returning to your log.") }
            } else { ContentUnavailableView("Flight unavailable", systemImage: "airplane") }
        }
    }
}
