import XCTest
@testable import FlightbookCore

final class GeometryTests: XCTestCase {
    func airport(_ code: String, _ lat: Double, _ lon: Double) -> Airport {
        Airport(id: code, ident: code, iata: code, name: code, city: code, country: "", latitude: lat, longitude: lon, kind: "large_airport", sourceVersion: "test")
    }
    func testPacificAndAtlanticAreContinuousAndEndpointsFit() throws {
        let jfk = airport("JFK", 40.6413, -73.7781), nrt = airport("NRT", 35.772, 140.3929), lhr = airport("LHR", 51.47, -0.4543)
        let date = try LocalDate(iso: "2026-01-01")
        let flights = [Flight(origin: nrt, destination: jfk, departure: date), Flight(origin: jfk, destination: lhr, departure: date)]
        let paths = RouteGeometry.paths(flights)
        XCTAssertEqual(paths.count, 2)
        for path in paths {
            for (a,b) in zip(path.points, path.points.dropFirst()) {
                XCTAssertLessThan(abs(a.x-b.x), 0.1, "No false shortcut across the dateline")
                XCTAssertTrue(a.x.isFinite && a.y.isFinite)
            }
            var camera = MapCamera()
            camera.fit(path.points, width: 350, height: 355)
            for point in path.points {
                let screen = camera.screen(point, width: 350, height: 355)
                XCTAssertGreaterThanOrEqual(screen.x, 35); XCTAssertLessThanOrEqual(screen.x, 315)
                XCTAssertGreaterThanOrEqual(screen.y, 20); XCTAssertLessThanOrEqual(screen.y, 310)
            }
        }
        let pacific = try XCTUnwrap(paths.first { $0.origin.id == "NRT" })
        XCTAssertLessThan(abs(pacific.points.first!.x-pacific.points.last!.x), 0.5)
        XCTAssertEqual(RouteGeometry.paths(flights + [flights[0]]).count, 2)
    }
    func testPolarAndAntipodalRoutesStayFinite() {
        for pair in [(airport("A",0,0),airport("B",0,180)), (airport("A",89,0),airport("B",89,180)), (airport("A",0,0),airport("B",0,0))] {
            let points = RouteGeometry.greatCircle(pair.0, pair.1)
            XCTAssertEqual(points.count, 121)
            XCTAssertTrue(points.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.y >= -0.00001 && $0.y <= 1.00001 })
        }
    }
    func testPinchAnchorAndZoomBounds() {
        var camera = MapCamera()
        let point = MapPoint(x: 0.7, y: 0.4)
        let anchor = camera.screen(point, width: 390, height: 350)
        camera.zoom(by: 2, anchor: anchor, width: 390, height: 350)
        let after = camera.screen(point, width: 390, height: 350)
        XCTAssertEqual(after.x, anchor.x, accuracy: 0.001); XCTAssertEqual(after.y, anchor.y, accuracy: 0.001)
        camera.zoom(by: 10000, anchor: anchor, width: 390, height: 350); XCTAssertEqual(camera.zoom, 80)
        camera.zoom(by: 0.000001, anchor: anchor, width: 390, height: 350); XCTAssertEqual(camera.zoom, 0.65)
    }
    func testWorldCopiesAreOnlyPresentation() {
        let camera = MapCamera(), p = MapPoint(x: 0.1, y: 0.5)
        let a = camera.screen(p, width: 390, height: 350)
        let b = camera.screen(p, width: 390, height: 350, copy: 1)
        XCTAssertEqual(b.x-a.x, 390, accuracy: 0.001)
    }
}
