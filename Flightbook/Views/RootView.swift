import SwiftUI

@MainActor @Observable final class AppState {
    var tab = 0
    var range: DateRange = .all
    var annualYear = FlightCalendar.current.component(.year, from: .now)
    var annualVisit = UUID()
    var map = RouteMapState()
}

struct RootView: View {
    @Environment(FlightStore.self) private var store
    @State private var state = AppState()
    @State private var adding = false
    @State private var settings = false
    @AppStorage("distanceUnit", store: Preferences.defaults) private var unitName = DistanceUnit.miles.rawValue
    @AppStorage("appearance", store: Preferences.defaults) private var appearance = "System"
    private var unit: DistanceUnit { DistanceUnit(rawValue: unitName) ?? .miles }
    private var flights: [Flight] { store.flights.filter { state.range.includes($0.departure) } }
    private var years: [Int] {
        let current = FlightCalendar.current.component(.year, from: .now)
        let oldest = min(current - 10, store.flights.map(\.departure.year).min() ?? current)
        return Array(stride(from: current, through: oldest, by: -1))
    }
    var body: some View {
        @Bindable var state = state
        TabView(selection: $state.tab) {
            Tab("Overview", systemImage: "square.grid.2x2", value: 0) {
                NavigationStack { overview.toolbar { toolbar } }
            }
            Tab("Flights", systemImage: "airplane", value: 1) {
                NavigationStack {
                    HistoryView(flights: flights, unit: unit, filter: { filter }, add: { adding = true })
                        .toolbar { toolbar }
                }
            }
            Tab("Map", systemImage: "globe.americas", value: 2) {
                NavigationStack { mapPage.toolbar { toolbar } }
            }
            Tab("Annual", systemImage: "calendar", value: 3) {
                NavigationStack {
                    AnnualView(year: $state.annualYear, years: years, unit: unit, add: { adding = true })
                        .toolbar { toolbar }
                }.id(state.annualVisit)
            }
        }.tint(Palette.accent)
            .preferredColorScheme(appearance == "System" ? nil : appearance == "Dark" ? .dark : .light)
            .sheet(isPresented: $adding) { FlightForm() }
            .sheet(isPresented: $settings) { SettingsView() }
            .onChange(of: state.tab) { old, new in
                if new == 3 && old != 3 {
                    state.annualYear = FlightCalendar.current.component(.year, from: .now)
                    state.annualVisit = UUID()
                }
            }
            .onChange(of: state.range) { _, _ in state.map.selected = nil; state.map.initialized = false }
            .safeAreaInset(edge: .bottom) {
                if store.deleted != nil {
                    HStack {
                        Text("Flight deleted").font(.subheadline)
                        Spacer()
                        Button("Undo") { do { try store.undoDelete() } catch { store.error = error.localizedDescription } }
                            .font(.subheadline.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                        Button("Dismiss", systemImage: "xmark") { store.dismissUndo() }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                    }.padding(.horizontal, 18).background(.regularMaterial, in: Capsule()).padding(.horizontal).padding(.bottom, 6)
                }
            }
            .alert("Couldn’t save your change", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "Please try again.") }
    }
    private var filter: some View { DateFilter(range: $state.range, years: years) }
    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(title: "A life in flight", subtitle: "Every journey adds to your story.")
                filter
                if flights.isEmpty { EmptyFlights(filtered: !store.flights.isEmpty) { adding = true } }
                else {
                    let stats = Statistics(flights)
                    MetricsCard(stats: stats, unit: unit)
                    HStack {
                        Text("Recent flights").font(.title3.weight(.semibold))
                        Spacer()
                        Button("See all") { state.tab = 1 }.frame(minHeight: 44)
                    }
                    VStack(spacing: 0) {
                        ForEach(flights.prefix(3)) { flight in
                            NavigationLink { FlightDetail(id: flight.id, unit: unit) } label: { FlightRow(flight: flight, unit: unit) }.buttonStyle(.plain)
                            if flight.id != flights.prefix(3).last?.id { Divider() }
                        }
                    }
                    Highlights(stats: stats, unit: unit)
                    FrequentRoutes(stats: stats, unit: unit)
                    Text("Great-circle route distances. \(stats.estimatedCount) of \(stats.flights.count) flights use estimated airborne time, excluding taxi and layovers.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 24).padding(.bottom, 30)
        }.background(Palette.background)
    }
    private var mapPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "Your world", subtitle: "One journey at a time.")
                filter
                if flights.isEmpty { EmptyFlights(filtered: true) { adding = true } }
                else {
                    let groups = RouteGroup.groups(flights)
                    let selected = groups.first { $0.id == state.map.selected }
                    HStack {
                        Text(selected?.label ?? "\(flights.count) flights · \(groups.count) routes").font(.headline)
                        Spacer()
                        if let selected {
                            NavigationLink {
                                FlightDrilldown(title: selected.label, ids: Set(selected.flights.map(\.id)), unit: unit)
                            } label: { Text("View flights").font(.subheadline).frame(minHeight: 44).contentShape(Rectangle()) }
                        }
                    }
                    RouteMap(flights: flights, state: state.map).frame(height: 355)
                    Text("Drag to pan · Pinch or use + / − to zoom").font(.caption).foregroundStyle(.secondary)
                    Text("Your connections").font(.title3.weight(.semibold))
                    ForEach(groups) { group in
                        VStack(spacing: 6) {
                            Button {
                                if state.map.selected == group.id { state.map.initialized = false }
                                state.map.selected = group.id
                            } label: {
                                HStack {
                                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").foregroundStyle(Palette.accent)
                                    Text(group.label).font(.headline)
                                    Spacer()
                                    Text("\(group.count) \(group.count == 1 ? "flight" : "flights")").font(.subheadline).foregroundStyle(.secondary)
                                }.frame(minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("route-\(group.flights[0].origin.code)-\(group.flights[0].destination.code)")
                            if state.map.selected == group.id {
                                NavigationLink { FlightDrilldown(title: group.label, ids: Set(group.flights.map(\.id)), unit: unit) } label: {
                                    Text("View flights").frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing).contentShape(Rectangle())
                                }
                            }
                            Divider()
                        }
                    }
                    Text("Connections follow great-circle paths, not recorded aircraft tracks. Geography: Natural Earth.").font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(24)
        }.background(Palette.background)
    }
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Settings", systemImage: "gearshape") { settings = true }.labelStyle(.iconOnly)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Add a flight", systemImage: "plus") { adding = true }.labelStyle(.iconOnly).accessibilityIdentifier("addFlight")
        }
    }
}

struct HistoryView<Filter: View>: View {
    let flights: [Flight]
    let unit: DistanceUnit
    @ViewBuilder let filter: () -> Filter
    let add: () -> Void
    @State private var query = ""
    private var results: [Flight] {
        let tokens = query.folded.split(separator: " ").map(String.init)
        return flights.filter { f in tokens.allSatisfy { f.searchText.contains($0) } }
    }
    var body: some View {
        List {
            Section {
                PageHeader(title: "Your flights", subtitle: "All the places you took off for.").listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                filter().listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))
            }
            Section {
                if results.isEmpty {
                    if query.isEmpty { EmptyFlights(filtered: true, add: add) }
                    else { ContentUnavailableView.search(text: query) }
                }
                ForEach(results) { flight in
                    NavigationLink { FlightDetail(id: flight.id, unit: unit) } label: { FlightRow(flight: flight, unit: unit) }
                }
            } header: { Text("\(results.count) \(results.count == 1 ? "flight" : "flights")") }
            Section { Text("Each takeoff-to-landing leg is a separate flight.").font(.footnote).foregroundStyle(.secondary).listRowBackground(Color.clear) }
        }.listStyle(.insetGrouped).searchable(text: $query, prompt: "Airport, city, or flight")
    }
}
