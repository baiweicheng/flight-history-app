import SwiftUI

@Observable final class RouteMapState {
    var camera = MapCamera()
    var selected: String?
    var initialized = false
    var dataset = ""
}

private enum WorldGeometry {
    static let rings: [[MapPoint]] = {
        guard let url = Bundle.main.url(forResource: "world", withExtension: "json"),
              let data = try? Data(contentsOf: url), let raw = try? JSONDecoder().decode([[[Double]]].self, from: data)
        else { return [] }
        return raw.map { ring in ring.compactMap { $0.count == 2 ? MapPoint(x: $0[0], y: $0[1]) : nil } }
    }()
}

struct RouteMap: View {
    let flights: [Flight]
    var state: RouteMapState
    var interactive = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var dragStart: MapCamera?
    @State private var pinchStart: MapCamera?
    private var paths: [RoutePath] { RouteGeometry.paths(flights) }
    private var signature: String {
        flights.map { "\($0.id):\($0.origin.latitude):\($0.origin.longitude):\($0.destination.latitude):\($0.destination.longitude)" }.sorted().joined(separator: ";")
    }
    private var ocean: Color { colorScheme == .dark ? Color(red: 0.06, green: 0.15, blue: 0.20) : Color(red: 0.89, green: 0.94, blue: 0.96) }
    private var land: Color { colorScheme == .dark ? Color(red: 0.20, green: 0.30, blue: 0.35) : Color(red: 0.98, green: 0.99, blue: 0.98) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let geometry = paths
            ZStack(alignment: .bottom) {
                Canvas { context, size in
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ocean))
                    drawWorld(context: &context, size: size)
                    drawRoutes(geometry, context: &context, size: size)
                }
                .contentShape(Rectangle())
                .gesture(interactive ? drag(size) : nil)
                .simultaneousGesture(interactive ? pinch(size) : nil)
                .simultaneousGesture(interactive ? SpatialTapGesture().onEnded { event in
                    guard pinchStart == nil, dragStart == nil else { return }
                    if let route = nearest(event.location, paths: geometry, size: size) { select(route, size: size) }
                } : nil)
                .accessibilityLabel("Flight connections map, \(geometry.count) routes.\(interactive ? " Explore using the route list, Focus routes and zoom buttons." : "")")
                .accessibilityAddTraits(.isImage)
                .accessibilityValue("Zoom \(Int(state.camera.zoom * 100)) percent")
                .accessibilityIdentifier("routeMap")
                if interactive {
                    HStack(alignment: .bottom) {
                        Button {
                            transition { state.selected = nil; fit(geometry, size: size) }
                        } label: { Label("Focus routes", systemImage: "arrow.up.left.and.arrow.down.right").font(.subheadline.weight(.medium)).padding(.horizontal, 13).frame(minHeight: 44) }
                            .buttonStyle(.plain).background(reduceTransparency ? AnyShapeStyle(Palette.surface) : AnyShapeStyle(.regularMaterial), in: Capsule())
                            .accessibilityIdentifier("focusRoutes")
                        Spacer(minLength: 6)
                        VStack(spacing: 0) {
                            zoomButton("Zoom in", icon: "plus", factor: 1.5, size: size)
                            Divider().frame(width: 28)
                            zoomButton("Zoom out", icon: "minus", factor: 1/1.5, size: size)
                        }.background(reduceTransparency ? AnyShapeStyle(Palette.surface) : AnyShapeStyle(.regularMaterial), in: Capsule())
                    }.padding(12)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 22))
                .onAppear { initialize(geometry, size: size) }
                .onChange(of: size) { old, new in
                    guard old != new else { return }
                    state.initialized = false; initialize(geometry, size: new)
                }
                .onChange(of: signature) { _, _ in state.initialized = false; state.selected = nil; initialize(geometry, size: size) }
                .onChange(of: state.selected) { _, selected in
                    if let selected, let path = geometry.first(where: { $0.id == selected }) { transition { fit([path], size: size) } }
                }
                .onChange(of: state.initialized) { _, value in if !value { initialize(geometry, size: size) } }
        }
    }
    private func initialize(_ paths: [RoutePath], size: CGSize) {
        guard !state.initialized || state.dataset != signature else { return }
        state.dataset = signature; state.initialized = true
        let selected = paths.filter { $0.id == state.selected }
        fit(selected.isEmpty ? paths : selected, size: size)
    }
    private func fit(_ paths: [RoutePath], size: CGSize) {
        state.camera.fit(paths.flatMap(\.points), width: size.width, height: size.height, bottomInset: interactive ? 90 : 35)
    }
    private func transition(_ work: () -> Void) { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22), work) }
    private func select(_ path: RoutePath, size: CGSize) {
        transition { state.selected = path.id; fit([path], size: size) }
    }
    private func zoomButton(_ title: String, icon: String, factor: Double, size: CGSize) -> some View {
        Button {
            transition { state.camera.zoom(by: factor, anchor: MapPoint(x: size.width/2, y: size.height/2), width: size.width, height: size.height) }
        } label: { Image(systemName: icon).font(.headline).frame(width: 44, height: 44) }
            .buttonStyle(.plain).accessibilityLabel(title).accessibilityIdentifier(title == "Zoom in" ? "zoomIn" : "zoomOut")
    }
    private func drag(_ size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6).onChanged { value in
            guard pinchStart == nil else { return }
            if dragStart == nil { dragStart = state.camera }
            guard let start = dragStart else { return }
            state.camera.center.x = start.center.x - value.translation.width / (size.width * start.zoom)
            state.camera.center.y = start.center.y - value.translation.height / (size.width * start.zoom)
            state.camera.constrain(width: size.width, height: size.height)
        }.onEnded { _ in
            state.camera.center.x -= floor(state.camera.center.x)
            dragStart = nil
        }
    }
    private func pinch(_ size: CGSize) -> some Gesture {
        MagnifyGesture().onChanged { value in
            if pinchStart == nil { pinchStart = state.camera; dragStart = nil }
            guard let start = pinchStart else { return }
            state.camera = start
            state.camera.zoom(by: value.magnification, anchor: MapPoint(x: value.startLocation.x, y: value.startLocation.y), width: size.width, height: size.height)
        }.onEnded { _ in pinchStart = nil; dragStart = nil }
    }
    private func screen(_ point: MapPoint, size: CGSize, copy: Int = 0) -> CGPoint {
        let p = state.camera.screen(point, width: size.width, height: size.height, copy: copy)
        return CGPoint(x: p.x, y: p.y)
    }
    private func drawWorld(context: inout GraphicsContext, size: CGSize) {
        let base = Int(floor(state.camera.center.x))
        for copy in (base-2)...(base+2) {
            var world = Path()
            for ring in WorldGeometry.rings where !ring.isEmpty {
                world.move(to: screen(ring[0], size: size, copy: copy))
                for p in ring.dropFirst() { world.addLine(to: screen(p, size: size, copy: copy)) }
                world.closeSubpath()
            }
            context.fill(world, with: .color(land), style: FillStyle(eoFill: true))
            context.stroke(world, with: .color(.secondary.opacity(0.18)), lineWidth: 0.6)
        }
    }
    private func copies(_ path: RoutePath) -> ClosedRange<Int> {
        let midpoint = ((path.points.first?.x ?? 0) + (path.points.last?.x ?? 0))/2
        let base = Int((state.camera.center.x-midpoint).rounded())
        return (base-2)...(base+2)
    }
    private func drawRoutes(_ paths: [RoutePath], context: inout GraphicsContext, size: CGSize) {
        var labels: [(Airport, CGPoint, Bool)] = []
        for route in paths {
            let selected = state.selected == route.id
            for copy in copies(route) {
                var path = Path()
                let points = route.points.map { screen($0, size: size, copy: copy) }
                guard let first = points.first, let last = points.last else { continue }
                path.move(to: first); for point in points.dropFirst() { path.addLine(to: point) }
                let opacity = state.selected == nil || selected ? 0.9 : 0.22
                context.stroke(path, with: .color(Palette.accent.opacity(opacity)), style: StrokeStyle(lineWidth: selected ? 3 : 1.7, lineCap: .round))
                labels.append((route.origin, first, selected)); labels.append((route.destination, last, selected))
            }
        }
        var occupied: [CGRect] = [], drawn: Set<String> = []
        let controls = CGRect(x: 0, y: size.height - (interactive ? 105 : 0), width: size.width, height: interactive ? 105 : 0)
        for (airport, point, _) in labels.sorted(by: { $0.2 && !$1.2 }) {
            guard point.x >= 5, point.x <= size.width-5, point.y >= 8, point.y <= size.height-8 else { continue }
            let key = airport.id + ":\(Int(point.x))"
            guard drawn.insert(key).inserted else { continue }
            let dot = CGRect(x: point.x-3, y: point.y-3, width: 6, height: 6)
            context.fill(Path(ellipseIn: dot.insetBy(dx: -2, dy: -2)), with: .color(land))
            context.fill(Path(ellipseIn: dot), with: .color(Palette.accent))
            let text = context.resolve(Text(airport.code).font(.system(size: 11, weight: .semibold)).foregroundColor(Palette.ink))
            let measure = text.measure(in: CGSize(width: 90, height: 20))
            let rect = CGRect(x: min(size.width-measure.width-7, max(6, point.x+7)), y: max(4, point.y-21), width: measure.width+6, height: 19)
            guard !controls.intersects(rect), !occupied.contains(where: { $0.intersects(rect) }) else { continue }
            occupied.append(rect.insetBy(dx: -4, dy: -3))
            context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(land.opacity(0.92)))
            context.draw(text, at: CGPoint(x: rect.minX+3, y: rect.midY), anchor: .leading)
        }
    }
    private func nearest(_ point: CGPoint, paths: [RoutePath], size: CGSize) -> RoutePath? {
        var distance = 18.0, result: RoutePath?
        for path in paths {
            for copy in copies(path) {
                let points = path.points.map { screen($0, size: size, copy: copy) }
                for (a,b) in zip(points, points.dropFirst()) {
                    let dx = b.x-a.x, dy = b.y-a.y
                    let t = min(1, max(0, ((point.x-a.x)*dx+(point.y-a.y)*dy) / max(0.0001, dx*dx+dy*dy)))
                    let d = hypot(point.x-a.x-t*dx, point.y-a.y-t*dy)
                    if d < distance { distance = d; result = path }
                }
            }
        }
        return result
    }
}
