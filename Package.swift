// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlightbookCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FlightbookCore", targets: ["FlightbookCore"])],
    targets: [
        .target(name: "FlightbookCore", path: "Flightbook/Core"),
        .testTarget(name: "FlightbookCoreTests", dependencies: ["FlightbookCore"])
    ]
)
