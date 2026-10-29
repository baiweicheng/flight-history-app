import SwiftUI
import UniformTypeIdentifiers

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        data = contents
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct DataTransferView: View {
    @Environment(FlightStore.self) private var store
    @State private var document = ExportDocument(data: Data())
    @State private var exportType = UTType.json
    @State private var exporting = false
    @State private var exportName = "Flightbook"
    @State private var importing = false
    @State private var working = false
    @State private var pending: FlightBackup?
    @State private var error: String?
    @State private var notice: String?
    var body: some View {
        Form {
            Section {
                Text("Your log is stored on this device. Keep a backup somewhere safe before replacing or removing the app.")
            }
            Section {
                Button("Export lossless backup", systemImage: "externaldrive") { export(csv: false) }.accessibilityIdentifier("exportBackup")
                Button("Export CSV", systemImage: "tablecells") { export(csv: true) }.accessibilityIdentifier("exportCSV")
            } header: { Text("Export all \(store.flights.count) flights") }
            footer: { Text("JSON backups preserve IDs, local dates, airport snapshots, original inputs, corrections and metric provenance. CSV is for spreadsheets; use JSON to restore. Text that could be a spreadsheet formula is prefixed with an apostrophe in CSV.") }
            Section {
                Button("Restore from backup", systemImage: "arrow.down.doc") { importing = true }.accessibilityIdentifier("restoreBackup")
                if store.hasRecovery {
                    Button("Recover log from before last restore", systemImage: "arrow.uturn.backward") {
                        do { pending = try store.recoveryBackup() } catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("recoverLog")
                }
            } footer: { Text("Review a backup before choosing Merge or Replace. Before each restore, the current log is saved as a recovery copy on this device. The next restore replaces that recovery copy.") }
            if working { ProgressView("Preparing your data…") }
            if let notice { Section { Label(notice, systemImage: "checkmark.circle").foregroundStyle(Palette.accent) } }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uitesting") {
                Section("UAT sandbox") {
                    Button("Preview test backup") {
                        do { pending = try BackupCodec.make(Array(store.flights.prefix(2))) } catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("previewTestBackup")
                    Button("Check invalid test backup") {
                        do { _ = try BackupCodec.decode(Data("broken".utf8)) } catch { self.error = error.localizedDescription }
                    }
                }
            }
            #endif
        }.navigationTitle("Backup & export").navigationBarTitleDisplayMode(.inline).disabled(working)
            .background {
                Color.clear.fileExporter(isPresented: $exporting, document: document, contentType: exportType, defaultFilename: exportName) { result in
                    switch result {
                    case .success: notice = "Export saved."
                    case .failure(let error):
                        if (error as NSError).code != NSUserCancelledError { self.error = error.localizedDescription }
                    }
                }
            }
            .background {
                Color.clear.fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                    switch result {
                    case .success(let urls): if let url = urls.first { read(url) }
                    case .failure(let error):
                        if (error as NSError).code != NSUserCancelledError { self.error = error.localizedDescription }
                    }
                }
            }
            .sheet(item: $pending) { backup in RestorePreview(backup: backup) { notice = $0 } }
            .alert("Data transfer couldn’t finish", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
    }
    private func export(csv: Bool) {
        let flights = store.flights
        working = true
        Task {
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    csv ? Data(CSVExport.encode(flights).utf8) : try BackupCodec.encode(flights)
                }.value
                document = ExportDocument(data: data); exportType = csv ? .commaSeparatedText : .json
                let formatter = DateFormatter()
                formatter.calendar = FlightCalendar.current; formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
                exportName = "Flightbook-" + formatter.string(from: .now)
                working = false; exporting = true
            } catch { working = false; self.error = error.localizedDescription }
        }
    }
    private func read(_ url: URL) {
        working = true
        Task {
            do {
                let backup = try await Task.detached(priority: .userInitiated) {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let values = try url.resourceValues(forKeys: [.fileSizeKey])
                    guard (values.fileSize ?? 0) <= BackupCodec.maximumBytes else { throw FlightError.invalidBackup }
                    return try BackupCodec.decode(Data(contentsOf: url, options: .mappedIfSafe))
                }.value
                working = false; pending = backup
            } catch { working = false; self.error = error.localizedDescription }
        }
    }
}

private struct RestorePreview: View {
    @Environment(FlightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let backup: FlightBackup
    let completed: (String) -> Void
    @State private var mode: RestoreMode = .merge
    @State private var confirming = false
    @State private var error: String?
    private var plan: RestorePlan { RestorePlan(existing: store.flights, incoming: backup.flights, mode: mode) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Backup") {
                    LabeledContent("Flights", value: String(backup.flights.count))
                    LabeledContent("Created", value: backup.exportedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Format version", value: String(backup.schemaVersion))
                }
                Section {
                    Picker("Restore mode", selection: $mode) { ForEach(RestoreMode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    if mode == .merge {
                        Text("Add \(plan.added) new flights. Keep \(plan.unchanged) identical entries and \(plan.conflicts) local entries that differ from the backup.")
                        if plan.possibleDuplicates > 0 { Label("\(plan.possibleDuplicates) incoming flights share a route and date with your log. Their different IDs are preserved as separate flights.", systemImage: "exclamationmark.triangle").font(.footnote) }
                    } else {
                        Text("Replace all \(store.flights.count) flights on this device with the \(backup.flights.count) flights in this backup.")
                    }
                    Text("Result: \(plan.resultingFlights.count) flights").font(.headline).accessibilityIdentifier("restoreResult")
                } footer: { Text("A recovery copy of the current log is saved before anything changes. Your display settings are kept.") }
                Section {
                    Button(mode == .merge ? "Merge backup" : "Replace log", role: mode == .replace ? .destructive : nil) {
                        if mode == .replace { confirming = true } else { apply() }
                    }.frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("applyRestore")
                }
            }.navigationTitle("Review restore").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .confirmationDialog("Replace the current log?", isPresented: $confirming, titleVisibility: .visible) {
                    Button("Replace log", role: .destructive) { apply() }
                } message: { Text("The current log will be available under Recover log from before last restore.") }
                .alert("Restore couldn’t finish", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK") { error = nil }
                } message: { Text(error ?? "") }
        }
    }
    private func apply() {
        do {
            try store.restore(backup, mode: mode)
            completed("Restore complete. Your log contains \(store.flights.count) flights."); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
