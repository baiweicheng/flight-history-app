import SwiftUI

struct FlightForm: View {
    @Environment(FlightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: Flight?
    var returnFrom: Flight?
    @State private var origin: Airport?
    @State private var destination: Airport?
    @State private var date = LocalDate(.now).pickerDate
    @State private var airline = ""
    @State private var number = ""
    @State private var notes = ""
    @State private var picking: AirportField?
    @State private var error: String?
    @State private var discard = false
    @State private var savedNotice = false
    @State private var initialized = false
    @AppStorage("distanceUnit", store: Preferences.defaults) private var unitName = DistanceUnit.miles.rawValue
    enum AirportField: String, Identifiable { case origin, destination; var id: String { rawValue } }
    private var unit: DistanceUnit { DistanceUnit(rawValue: unitName) ?? .miles }
    private var valid: Bool { origin != nil && destination != nil && origin?.id != destination?.id }
    private var draft: Flight? {
        guard let origin, let destination else { return nil }
        return Flight(id: existing?.id ?? UUID(), origin: origin, destination: destination, departure: LocalDate(date, calendar: FlightCalendar.utc))
    }
    private var duplicate: Bool { draft.map { d in store.flights.contains { d.likelyDuplicate(of: $0) } } ?? false }
    private var dirty: Bool {
        if let existing {
            return origin != existing.origin || destination != existing.destination || LocalDate(date, calendar: FlightCalendar.utc) != existing.departure
                || airline != (existing.airline ?? "") || number != (existing.flightNumber ?? "") || notes != (existing.notes ?? "")
        }
        return origin != nil || destination != nil || !airline.isEmpty || !number.isEmpty || !notes.isEmpty
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    airportButton("From", airport: origin, field: .origin)
                    Button("Swap airports", systemImage: "arrow.up.arrow.down") { swap(&origin, &destination) }.frame(minHeight: 44)
                    airportButton("To", airport: destination, field: .destination)
                } header: { Text("Three details. One more journey remembered.").textCase(nil) }
                Section {
                    DatePicker("Departure date", selection: $date, in: ...LocalDate(.now).pickerDate, displayedComponents: .date)
                        .environment(\.calendar, FlightCalendar.utc).environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                        .accessibilityIdentifier("departureDate")
                } footer: { Text(returnFrom != nil ? "Choose the return flight’s own local departure date." : "Use the local calendar date where your flight departed.") }
                if let origin, let destination, valid {
                    Section {
                        LabeledContent("Route distance", value: unit.format(FlightMetrics.distance(origin, destination)))
                        LabeledContent("Estimated airborne time", value: "~ " + durationText(FlightMetrics.estimatedMinutes(km: FlightMetrics.distance(origin, destination))))
                    } footer: { Text("A distance-based planning estimate, excluding taxi and layovers.") }
                } else if origin?.id == destination?.id && origin != nil {
                    Text("Choose different departure and arrival airports.").foregroundStyle(.red)
                }
                Section {
                    DisclosureGroup("More details (optional)") {
                        TextField("Airline", text: $airline).textContentType(.organizationName)
                        TextField("Flight number", text: $number).textInputAutocapitalization(.characters)
                        TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...8)
                    }
                }
                if duplicate {
                    Label("A flight on this route and date is already logged. You can still save another leg.", systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.orange)
                }
                if savedNotice { Label("Flight saved. Ready for the next one.", systemImage: "checkmark.circle.fill").foregroundStyle(Palette.accent) }
                Section {
                    if existing == nil {
                        Button("Save and add another") { save(another: true) }.frame(maxWidth: .infinity, minHeight: 44).disabled(!valid)
                    }
                }
            }.navigationTitle(existing == nil ? (returnFrom == nil ? "Add a flight" : "Add return flight") : "Edit flight")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if dirty { discard = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save(another: false) }.disabled(!valid).accessibilityIdentifier("saveFlight")
                    }
                }
                .confirmationDialog("Discard unsaved changes?", isPresented: $discard, titleVisibility: .visible) {
                    Button("Discard changes", role: .destructive) { dismiss() }
                }
                .interactiveDismissDisabled(dirty)
                .sheet(item: $picking) { field in
                    AirportPicker(title: field == .origin ? "From airport" : "To airport") { airport in
                        if field == .origin { origin = airport } else { destination = airport }
                        savedNotice = false
                    }
                }
                .alert("Flight couldn’t be saved", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK") { error = nil }
                } message: { Text(error ?? "") }
                .onAppear {
                    guard !initialized else { return }; initialized = true
                    if let f = existing {
                        origin = f.origin; destination = f.destination; date = f.departure.pickerDate
                        airline = f.airline ?? ""; number = f.flightNumber ?? ""; notes = f.notes ?? ""
                    } else if let f = returnFrom { origin = f.destination; destination = f.origin; date = LocalDate(.now).pickerDate }
                }
        }.tint(Palette.accent)
    }
    private func airportButton(_ title: String, airport: Airport?, field: AirportField) -> some View {
        Button { picking = field } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(airport?.code ?? "Choose airport").font(.title2.weight(.semibold))
                    Text(airport.map { "\($0.city) · \($0.name)" } ?? "Search by code, city, or airport")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }.padding(.vertical, 8).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("Choose \(title.lowercased()) airport")
            .accessibilityValue(airport?.code ?? "Not selected").accessibilityIdentifier(field.rawValue + "Airport")
    }
    private func save(another: Bool) {
        guard let origin, let destination, valid else { return }
        do {
            var f = existing ?? Flight(origin: origin, destination: destination, departure: LocalDate(date, calendar: FlightCalendar.utc))
            f.reviseRoute(origin: origin, destination: destination)
            f.origin = origin; f.destination = destination; f.departure = LocalDate(date, calendar: FlightCalendar.utc)
            func optional(_ text: String) -> String? { let t = text.trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? nil : t }
            f.airline = optional(airline); f.flightNumber = optional(number); f.notes = optional(notes); f.updatedAt = .now
            try store.save(f)
            if another { self.origin = nil; self.destination = nil; airline = ""; number = ""; notes = ""; savedNotice = true }
            else { dismiss() }
        } catch { self.error = error.localizedDescription }
    }
}

struct AirportPicker: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let choose: (Airport) -> Void
    @State private var query = ""
    @State private var results: [Airport] = []
    @State private var loading = true
    @State private var failure: String?
    var body: some View {
        NavigationStack {
            List {
                if loading { ProgressView("Searching airports…") }
                if let failure { ContentUnavailableView("Catalog unavailable", systemImage: "exclamationmark.triangle", description: Text(failure)) }
                if !loading && failure == nil && results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
                ForEach(results) { airport in
                    Button { choose(airport); dismiss() } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Text(airport.code).font(.headline.monospaced()).frame(minWidth: 50, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(airport.name).foregroundStyle(.primary)
                                Text("\(airport.city.isEmpty ? airport.ident : airport.city), \(airport.country)\(airport.isClosed ? " · Closed / historical" : "")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 6).frame(minHeight: 44).contentShape(Rectangle())
                    }.accessibilityIdentifier("airport-\(airport.code)")
                }
                if results.count == 60 { Text("Showing 60 matches. Add a city or airport name to narrow your search.").font(.footnote).foregroundStyle(.secondary) }
            }.searchable(text: $query, prompt: "Code, city, or airport name")
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .task(id: query) {
                    do {
                        loading = true
                        if !query.isEmpty { try await Task.sleep(for: .milliseconds(180)) }
                        let matches = try await AirportCatalog.shared.search(query)
                        try Task.checkCancellation(); results = matches; loading = false; failure = nil
                    } catch is CancellationError { }
                    catch { failure = error.localizedDescription; loading = false }
                }
        }
    }
}
