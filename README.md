# Flightbook

A native, offline iPhone logbook for past flights. Built with SwiftUI and SwiftData, targeting iOS 26 and later. Flightbook is a working name.

## Development

Open `Flightbook.xcodeproj` in Xcode. Select the Flightbook scheme and an iPhone simulator. No signing account is required for Simulator builds; configure your own development team to run on a phone.

The app has no third-party runtime dependencies and makes no network requests. The bundled airport catalog includes historical and closed airports. New installations start with an empty personal log.

```sh
swift test
xcodebuild -project Flightbook.xcodeproj -scheme Flightbook \
  -destination 'platform=iOS Simulator,name=Flightbook iPhone 17' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```

`Scripts/generate_project.py` deterministically regenerates the project after adding/removing Swift files or resources. Python's standard library is sufficient. Tests use a separate `Flightbook-UAT` SwiftData store when launched with `-uitesting`. The additional `-reset-test-data` argument clears only that isolated test log. It never clears the normal personal log.

## Data and estimates

Flights preserve their UUID, local departure calendar date, airport identity and coordinate snapshots, optional inputs, and versioned measurement provenance. Local dates are stored as `YYYY-MM-DD`, independent of device time zone. Distances use the haversine formula with the IUGG mean Earth radius of 6371.0088 km; display rounding does not affect rankings.

Airborne hours are a planning estimate, not a matched historical flight. Model `airborne-heuristic-1` uses a route-dependent effective cruise speed from 450 to 800 km/h, adds 15 minutes for airborne climb/descent, and rounds to five minutes with a 15-minute floor. It excludes taxi, layovers, wind, aircraft type and historical schedules. It has sanity and boundary tests, but has not been calibrated against historical observations. Comparable airborne observations and explicit user corrections have separate provenance; gate-to-gate data is never silently added to airborne totals.

Airport data: [OurAirports](https://ourairports.com/data/), public domain, retrieved October 28, 2026. See `Flightbook/Resources/catalog-provenance.json` for the source hash and catalog version. Refresh offline with `python3 Scripts/prepare_catalog.py /path/to/airports.csv`, reviewing the source date/version in the script first. Existing flight snapshots are preserved when a new catalog ships. No automatic catalog refresh occurs.

Project discussion, planning, design references and conversation memory remain in the local, Git-ignored `.project-context/` directory.
