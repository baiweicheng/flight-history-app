import SwiftUI

@Observable final class AppState {
    var tab = 0
    var range: DateRange = .all
    var annualYear = Calendar.current.component(.year, from: .now)
}

struct RootView: View {
    @Environment(FlightStore.self) private var store
    @State private var state = AppState()
    @State private var adding = false
    @State private var settings = false
    @AppStorage("distanceUnit") private var unitName = DistanceUnit.miles.rawValue
    @AppStorage("appearance") private var appearance = "System"
    private var unit: DistanceUnit { DistanceUnit(rawValue: unitName) ?? .miles }
    var body: some View {
        @Bindable var state = state
        TabView(selection: $state.tab) {
            Tab("Overview", systemImage: "square.grid.2x2", value: 0) {
                NavigationStack { overview }
            }
            Tab("Flights", systemImage: "airplane", value: 1) {
                NavigationStack { history }
            }
            Tab("Map", systemImage: "globe.americas", value: 2) {
                NavigationStack { ContentUnavailableView("Your world", systemImage: "globe.americas", description: Text("Route exploration is coming in the next build phase.")) }
            }
            Tab("Annual", systemImage: "calendar", value: 3) {
                NavigationStack { ContentUnavailableView("Annual summary", systemImage: "calendar", description: Text("Yearly summaries are coming in the next build phase.")) }
            }
        }.tint(Palette.accent)
            .preferredColorScheme(appearance == "System" ? nil : appearance == "Dark" ? .dark : .light)
            .sheet(isPresented: $adding) { FlightForm() }
            .sheet(isPresented: $settings) { settingsView }
            .alert("Couldn’t save your change", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "Please try again.") }
    }
    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(title: "A life in flight", subtitle: "Every journey adds to your story.")
                if store.flights.isEmpty { EmptyFlights { adding = true } }
                else {
                    MetricsCard(stats: Statistics(store.flights), unit: unit)
                    HStack {
                        Text("Recent flights").font(.title3.weight(.semibold))
                        Spacer()
                        Button("See all") { state.tab = 1 }.frame(minHeight: 44)
                    }
                    VStack(spacing: 0) {
                        ForEach(store.flights.prefix(3)) { flight in
                            NavigationLink { FlightDetail(id: flight.id, unit: unit) } label: { FlightRow(flight: flight, unit: unit) }.buttonStyle(.plain)
                            if flight.id != store.flights.prefix(3).last?.id { Divider() }
                        }
                    }
                    Text("Great-circle route distances. Airborne time is an estimate, excluding taxi and layovers.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 24).padding(.bottom, 30)
        }.background(Palette.background).toolbar { toolbar }
    }
    private var history: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "Your flights", subtitle: "All the places you took off for.")
                if store.flights.isEmpty { EmptyFlights { adding = true } }
                ForEach(store.flights) { flight in
                    NavigationLink { FlightDetail(id: flight.id, unit: unit) } label: { FlightRow(flight: flight, unit: unit) }.buttonStyle(.plain)
                }
            }.padding(24)
        }.background(Palette.background).toolbar { toolbar }
    }
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Settings", systemImage: "gearshape") { settings = true }.labelStyle(.iconOnly)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Add a flight", systemImage: "plus") { adding = true }.labelStyle(.iconOnly).accessibilityIdentifier("addFlight")
        }
    }
    private var settingsView: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Picker("Distance", selection: $unitName) { ForEach(DistanceUnit.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }
                    Picker("Appearance", selection: $appearance) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } }
                }
                Section("About your log") {
                    Text("Flights are stored locally. No account or internet connection is required.")
                    Text("Airport catalog: OurAirports, October 28, 2026. Public-domain data; airport information may contain errors.")
                    Text("Hours use Flightbook’s airborne planning estimate. Wind, aircraft and historical schedules are not modeled.")
                }.font(.footnote)
            }.navigationTitle("Settings").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { settings = false } } }
        }
    }
}
