import SwiftUI

@main struct FlightbookApp: App {
    private let store: FlightStore?
    private let startupError: String?
    init() {
        Preferences.prepareTestSession()
        do {
            let loaded = try FlightStore()
            #if DEBUG
            try UATSupport.seed(loaded)
            #endif
            store = loaded; startupError = nil
        }
        catch { store = nil; startupError = error.localizedDescription }
    }
    var body: some Scene {
        WindowGroup {
            if let store { RootView().environment(store) }
            else {
                ContentUnavailableView {
                    Label("Your log couldn’t open", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved data has been left in place. Restart Flightbook and try again.\n\n\(startupError ?? "")")
                }
            }
        }
    }
}
