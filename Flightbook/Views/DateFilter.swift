import SwiftUI

struct DateFilter: View {
    @Binding var range: DateRange
    let years: [Int]
    @State private var presenting = false
    var body: some View {
        Button { presenting = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                Text(range.label).fontWeight(.medium)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }.font(.subheadline).padding(.horizontal, 14).frame(minHeight: 44)
                .background(Palette.surface, in: Capsule())
        }.buttonStyle(.plain).foregroundStyle(Palette.accent).accessibilityLabel("Date range, \(range.label)")
            .accessibilityIdentifier("dateFilter")
            .sheet(isPresented: $presenting) { DateFilterSheet(range: $range, years: years) }
    }
}

private struct DateFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var range: DateRange
    let years: [Int]
    @State private var custom = false
    @State private var from = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: .now), month: 1, day: 1))!
    @State private var through = Date.now
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("All time") { range = .all; dismiss() }.frame(minHeight: 44)
                    ForEach(years, id: \.self) { year in Button(String(year)) { range = .year(year); dismiss() }.frame(minHeight: 44) }
                }
                Section {
                    Toggle("Custom dates", isOn: $custom)
                    if custom {
                        DatePicker("From", selection: $from, in: ...Date.now, displayedComponents: .date)
                        DatePicker("Through", selection: $through, in: ...Date.now, displayedComponents: .date)
                        if LocalDate(from) > LocalDate(through) { Text("Start date must be on or before the end date.").foregroundStyle(.red) }
                        Button("Apply custom range") { range = .custom(LocalDate(from), LocalDate(through)); dismiss() }
                            .disabled(LocalDate(from) > LocalDate(through)).frame(minHeight: 44)
                    }
                } footer: { Text("Both dates are included. This filter is shared by Overview, Flights and Map. Annual has its own year.") }
            }.navigationTitle("Date range").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .onAppear { if case .custom(let a, let b) = range { from = a.pickerDate; through = b.pickerDate; custom = true } }
        }.presentationDetents([.large])
    }
}
