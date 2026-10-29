import SwiftUI

struct FlightDetail: View {
    @Environment(FlightStore.self) private var store
    let id: UUID
    let unit: DistanceUnit
    @State private var editing = false
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
                    Section {
                        LabeledContent("Route distance", value: unit.format(flight.distanceKM))
                        LabeledContent("Estimated airborne time", value: "~ " + durationText(flight.duration.value))
                        LabeledContent("Departure date", value: flight.departure.formatted)
                        if let airline = flight.airline { LabeledContent("Airline", value: airline) }
                        if let number = flight.flightNumber { LabeledContent("Flight", value: number) }
                    } footer: { Text("Great-circle airport distance. Hours are a planning estimate, excluding taxi and layovers.\nModel: \(flight.duration.version). Departure is a local calendar date.") }
                    if let notes = flight.notes { Section("Notes") { Text(notes) } }
                }.navigationTitle("Flight details").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } } }
                    .sheet(isPresented: $editing) { FlightForm(existing: flight) }
            } else { ContentUnavailableView("Flight unavailable", systemImage: "airplane") }
        }
    }
}
