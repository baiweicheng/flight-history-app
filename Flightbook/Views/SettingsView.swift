import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("distanceUnit") private var unitName = DistanceUnit.miles.rawValue
    @AppStorage("appearance") private var appearance = "System"
    var body: some View {
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
                    Text("Offline map: Natural Earth, public-domain geography. Routes show connections, not actual tracks.")
                }.font(.footnote)
            }.navigationTitle("Settings").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
