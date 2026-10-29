import Foundation

public struct MapPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}
public struct RoutePath: Sendable, Identifiable {
    public var id: String
    public var points: [MapPoint]
    public var origin: Airport
    public var destination: Airport
    public var count: Int
}
public enum RouteGeometry {
    public static func project(latitude: Double, longitude: Double) -> MapPoint {
        let phi = min(85.05112878, max(-85.05112878, latitude)) * .pi / 180
        return MapPoint(x: (longitude + 180) / 360, y: (1 - asinh(tan(phi)) / .pi) / 2)
    }
    public static func wrapDelta(_ value: Double) -> Double { value - floor((value + 180) / 360) * 360 }

    /// Spherical interpolation, continuously unwrapped across the antimeridian.
    public static func greatCircle(_ a: Airport, _ b: Airport, startLongitude: Double? = nil, steps: Int = 120) -> [MapPoint] {
        func vector(_ a: Airport) -> [Double] {
            let p = a.latitude * .pi / 180, l = a.longitude * .pi / 180
            return [cos(p) * cos(l), cos(p) * sin(l), sin(p)]
        }
        let va = vector(a), vb = vector(b)
        let dot = min(1, max(-1, zip(va, vb).reduce(0) { $0 + $1.0 * $1.1 }))
        let angle = acos(dot)
        var longitude = startLongitude ?? a.longitude
        return (0...max(2, steps)).map { i in
            let t = Double(i) / Double(max(2, steps))
            var v: [Double]
            if angle < 0.0000001 { v = va }
            else if abs(.pi - angle) < 0.000001 {
                // An antipodal pair has infinitely many great circles. Choose a stable perpendicular.
                let basis: [Double] = abs(va[2]) < 0.9 ? [0, 0, 1] : [0, 1, 0]
                var normal = [va[1] * basis[2] - va[2] * basis[1], va[2] * basis[0] - va[0] * basis[2], va[0] * basis[1] - va[1] * basis[0]]
                let norm = sqrt(normal.reduce(0) { $0 + $1 * $1 }); normal = normal.map { $0 / norm }
                v = (0..<3).map { va[$0] * cos(.pi * t) + normal[$0] * sin(.pi * t) }
            } else {
                let u = sin((1-t) * angle) / sin(angle), w = sin(t * angle) / sin(angle)
                v = (0..<3).map { va[$0] * u + vb[$0] * w }
            }
            // Force exact endpoints, including the deterministic antipodal fallback.
            if i == 0 { v = va }; if i == max(2, steps) { v = vb }
            let raw = atan2(v[1], v[0]) * 180 / .pi
            longitude += wrapDelta(raw - longitude)
            let lat = atan2(v[2], hypot(v[0], v[1])) * 180 / .pi
            return project(latitude: lat, longitude: longitude)
        }
    }

    public static func paths(_ flights: [Flight]) -> [RoutePath] {
        let groups = RouteGroup.groups(flights)
        var airports: [String: Airport] = [:], degree: [String: Int] = [:]
        for g in groups {
            for a in [g.flights[0].origin, g.flights[0].destination] { airports[a.id] = a; degree[a.id, default: 0] += 1 }
        }
        let seeds = airports.keys.sorted { degree[$0] == degree[$1] ? $0 < $1 : degree[$0, default: 0] > degree[$1, default: 0] }
        guard let anchorID = seeds.first, let anchor = airports[anchorID] else { return [] }
        var longitudes: [String: Double] = [:]
        for seed in seeds where longitudes[seed] == nil {
            longitudes[seed] = anchor.longitude + wrapDelta(airports[seed]!.longitude - anchor.longitude)
            var queue = [seed], index = 0
            while index < queue.count {
                let current = queue[index]; index += 1
                for g in groups {
                    let f = g.flights[0]
                    let other = f.origin.id == current ? f.destination : f.destination.id == current ? f.origin : nil
                    if let other, longitudes[other.id] == nil {
                        longitudes[other.id] = longitudes[current]! + wrapDelta(other.longitude - airports[current]!.longitude)
                        queue.append(other.id)
                    }
                }
            }
        }
        return groups.map { g in
            let f = g.flights[0]
            return RoutePath(id: g.id, points: greatCircle(f.origin, f.destination, startLongitude: longitudes[f.origin.id]),
                             origin: f.origin, destination: f.destination, count: g.count)
        }
    }
}

public struct MapCamera: Equatable, Sendable {
    public var center = MapPoint(x: 0.5, y: 0.45)
    public var zoom = 1.0
    public init() {}
    public mutating func fit(_ points: [MapPoint], width: Double, height: Double, bottomInset: Double = 75) {
        guard let first = points.first, width > 0, height > 0 else { return }
        let minX = points.map(\.x).min() ?? first.x, maxX = points.map(\.x).max() ?? first.x
        let minY = points.map(\.y).min() ?? first.y, maxY = points.map(\.y).max() ?? first.y
        let usableHeight = max(50, height - 35 - bottomInset)
        let scale = min(max(40, width - 85) / max(0.015, maxX-minX), usableHeight / max(0.015, maxY-minY))
        zoom = min(80, max(0.65, scale / width))
        center = MapPoint(x: (minX+maxX)/2, y: (minY+maxY)/2 + (bottomInset - 35) / (2 * width * zoom))
        constrain(width: width, height: height)
    }
    public mutating func constrain(width: Double, height: Double) {
        zoom = min(80, max(0.65, zoom))
        let half = height / max(1, 2 * width * zoom)
        center.y = half >= 0.5 ? 0.5 : max(half, min(1 - half, center.y))
    }
    public mutating func zoom(by factor: Double, anchor: MapPoint, width: Double, height: Double) {
        let old = width * zoom, newZoom = min(80, max(0.65, zoom * factor)), new = width * newZoom
        guard old > 0, new > 0 else { return }
        let dx = anchor.x - width/2, dy = anchor.y - height/2
        center.x += dx/old - dx/new; center.y += dy/old - dy/new; zoom = newZoom
        constrain(width: width, height: height)
    }
    public func screen(_ point: MapPoint, width: Double, height: Double, copy: Int = 0) -> MapPoint {
        MapPoint(x: (point.x + Double(copy) - center.x) * width * zoom + width/2,
                 y: (point.y - center.y) * width * zoom + height/2)
    }
}
