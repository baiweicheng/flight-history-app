# Flightbook

A native, offline iPhone logbook for past flights. Built with SwiftUI and SwiftData, targeting iOS 26 and later. Flightbook is a working name.

## Development

Open `Flightbook.xcodeproj` in Xcode. Select the Flightbook scheme and an iPhone simulator. No signing account is required for Simulator builds; configure your own development team to run on a phone.

The app has no third-party runtime dependencies and makes no network requests. The bundled airport catalog includes historical and closed airports. New installations start with an empty personal log.

## Using the app

Tap **+**, choose two airports and their local departure date, then Save. Airline, flight number and notes are optional. A connection is logged as separate legs. Flight details offer editing, a return entry with its own date, and deletion with Undo.

Overview, Flights and Map share all-time, year and inclusive custom-date filters. Annual has its own year and opens to the current year when entered from another tab. Returning from an annual drill-down preserves that year's selection. Route distances, airport counts and shortest/longest highlights update from your saved flights; tied flights have a drill-down.

The Map wraps horizontally and supports dragging, pinching, zoom buttons, route selection and Focus routes. Its camera stays in place across tab changes and detail returns. A route groups both directions of the same airport pair; wrapped copies never add to totals.

In **Settings → Backup & export**, export all flights as a lossless JSON backup or spreadsheet CSV. Restore validates the format, dates, airport coordinates, measurements and SHA-256 integrity before previewing changes:

- **Merge** adds unseen UUIDs, skips identical entries and keeps the local version of conflicting UUIDs. Different IDs with the same route and date stay separate, with a duplicate warning in the preview.
- **Replace** restores exactly the backup's flights, including an empty log, after confirmation.
- Every restore first saves the current log as a local recovery copy. **Recover log from before last restore** previews that copy using the same flow. Each subsequent restore replaces the previous recovery copy. Keep exported backups outside the app for protection against uninstalling or losing the device.

CSV escapes quotes/newlines and prefixes formula-like text with an apostrophe for spreadsheet safety. Numeric coordinate/distance fields remain numeric. CSV is not the lossless restore format.

```sh
swift test
xcodebuild -project Flightbook.xcodeproj -scheme Flightbook \
  -destination 'platform=iOS Simulator,name=Flightbook iPhone 17' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```

`Scripts/generate_project.py` deterministically regenerates the project after adding/removing Swift files or resources. Python's standard library is sufficient. Tests use a separate `Flightbook-UAT` SwiftData store when launched with `-uitesting`. The additional `-reset-test-data` argument clears only that isolated test log. It never clears the normal personal log.

Debug builds can add `-seed-uat` to populate that separate log with eight clearly labeled illustrative flights. Test preferences and recovery files are isolated too. Fixture seeding and test-only preview controls are excluded from Release builds.

## Data and estimates

Flights preserve their UUID, local departure calendar date, airport identity and coordinate snapshots, optional inputs, and versioned measurement provenance. Local dates are stored as `YYYY-MM-DD`, independent of device time zone. Distances use the haversine formula with the IUGG mean Earth radius of 6371.0088 km; display rounding does not affect rankings.

Airborne hours are a planning estimate, not a matched historical flight. Model `airborne-heuristic-1` uses a route-dependent effective cruise speed from 450 to 800 km/h, adds 15 minutes for airborne climb/descent, and rounds to five minutes with a 15-minute floor. It excludes taxi, layovers, wind, aircraft type and historical schedules. It has sanity and boundary tests, but has not been calibrated against historical observations. Comparable airborne observations and explicit user corrections have separate provenance; gate-to-gate data is never silently added to airborne totals.

Airport data: [OurAirports](https://ourairports.com/data/), public domain, retrieved October 28, 2026. See `Flightbook/Resources/catalog-provenance.json` for the source hash and catalog version. Refresh offline with `python3 Scripts/prepare_catalog.py /path/to/airports.csv`, reviewing the source date/version in the script first. Existing flight snapshots are preserved when a new catalog ships. No automatic catalog refresh occurs.

Map geography: [Natural Earth](https://www.naturalearthdata.com/about/terms-of-use/), public domain, converted from the approved @d3-maps/atlas 1.0.0 reference to bundled Mercator rings. The app draws its own native SwiftUI Canvas map and great-circle geometry; it has no web view, map service, JavaScript or paid mapping dependency. The code-drawn app icon can be regenerated with `swift Scripts/make_icon.swift`.

The minimum deployment target is iOS 26. Simulator checks do not replace real-device validation, signing or family distribution. Configure a development team in Xcode for device installation. iCloud sync, automatic import, historical-duration enrichment and public App Store distribution are outside V1.

Project discussion, planning, design references and conversation memory remain in the local, Git-ignored `.project-context/` directory.
