import SwiftUI

enum Palette {
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.50, green: 0.84, blue: 0.91, alpha: 1)
        : UIColor(red: 0.035, green: 0.435, blue: 0.545, alpha: 1) })
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color.primary
}
struct Surface: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 24))
    }
}
extension View { func surface() -> some View { modifier(Surface()) } }

struct PageHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FLIGHTBOOK").font(.caption.weight(.medium)).tracking(2).foregroundStyle(.secondary)
            Text(title).font(.largeTitle.weight(.medium)).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
    }
}

struct MetricsCard: View {
    let stats: Statistics
    let unit: DistanceUnit
    @ScaledMetric(relativeTo: .largeTitle) private var distanceSize = 45
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Total route distance", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(unit.format(stats.distanceKM)).font(.system(size: distanceSize, weight: .medium, design: .rounded))
                .minimumScaleFactor(0.55).lineLimit(1).foregroundStyle(Palette.accent)
                .accessibilityIdentifier("totalDistance")
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) { metrics }
                VStack(alignment: .center, spacing: 18) { metrics }
            }
        }.surface()
    }
    @ViewBuilder private var metrics: some View {
        metric("\(stats.flights.count)", "flights")
        metric(durationText(stats.minutes), stats.estimatedCount == stats.flights.count ? "est. airborne time" : "airborne time*")
        metric("\(stats.airportCount)", "airports")
    }
    private func metric(_ number: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Text(number).font(.title3.weight(.semibold)).fixedSize(horizontal: true, vertical: false)
            Text(label).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: true, vertical: false)
        }.frame(maxWidth: .infinity).multilineTextAlignment(.center).accessibilityElement(children: .combine)
    }
}

struct FlightRow: View {
    let flight: Flight
    let unit: DistanceUnit
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "airplane").foregroundStyle(Palette.accent).frame(width: 42, height: 42)
                .background(Palette.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(flight.routeLabel).font(.headline)
                Text("\(flight.origin.city) to \(flight.destination.city)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 5) {
                Text(unit.format(flight.distanceKM)).font(.subheadline.monospacedDigit())
                Text(flight.departure.formatted).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 9).frame(minHeight: 64).contentShape(Rectangle())
            .accessibilityElement(children: .combine)
    }
}

struct EmptyFlights: View {
    var filtered = false
    let add: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label(filtered ? "No flights in this view" : "Your story starts here", systemImage: "airplane.departure")
        } description: {
            Text(filtered ? "Try another date range or add a past flight." : "Log a journey with just two airports and a date. Your history stays on this device.")
        } actions: {
            Button("Add a flight", systemImage: "plus", action: add).buttonStyle(.borderedProminent)
        }.padding(.vertical, 24)
    }
}
