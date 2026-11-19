import SwiftUI
import MapKit
import AppKit

// MARK: - Map View Proxy

@MainActor
class MapViewProxy: ObservableObject {
    weak var mapView: MKMapView?
    var originCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)

    func recenterToOrigin() {
        let region = MKCoordinateRegion(center: originCoordinate, span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30))
        mapView?.setRegion(region, animated: true)
    }
    func zoomIn() {
        guard let mv = mapView else { return }
        var region = mv.region
        region.span.latitudeDelta *= 0.5
        region.span.longitudeDelta *= 0.5
        mv.setRegion(region, animated: true)
    }
    func zoomOut() {
        guard let mv = mapView else { return }
        var region = mv.region
        region.span.latitudeDelta = min(region.span.latitudeDelta * 2, 180)
        region.span.longitudeDelta = min(region.span.longitudeDelta * 2, 360)
        mv.setRegion(region, animated: true)
    }
}

// MARK: - Map Container

struct MapContainerView: View {
    @EnvironmentObject var connectionStore: ConnectionStore
    @EnvironmentObject var tracerouteStore: TracerouteStore
    @StateObject private var mapProxy = MapViewProxy()

    var body: some View {
        let filtered = connectionStore.filteredConnections
        let all = connectionStore.connections
        let selected = connectionStore.selectedProcess

        ZStack(alignment: .bottomLeading) {
            MapViewRepresentable(
                connections: filtered,
                selectedProcess: selected,
                allConnections: all,
                processColor: { connectionStore.colorForProcess($0) },
                mapProxy: mapProxy,
                onSelectProcess: { connectionStore.selectProcess($0) }
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 6) {
                MapButton(systemName: "plus") { mapProxy.zoomIn() }
                MapButton(systemName: "minus") { mapProxy.zoomOut() }
                MapButton(systemName: "location.fill") { mapProxy.recenterToOrigin() }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor).opacity(0.9)))
            .padding(16)
        }
    }
}

struct MapButton: View {
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName).font(.system(size: 13, weight: .semibold)).frame(width: 28, height: 28)
        }.buttonStyle(.plain)
    }
}

// MARK: - Connection Overlay

/// One aggregated connection arc (per process and destination city).
/// The curve is drawn in screen space by ConnectionOverlayRenderer.
final class ConnectionOverlay: NSObject, MKOverlay {
    let connection: Connection
    let startCoord: CLLocationCoordinate2D
    let endCoord: CLLocationCoordinate2D
    var strokeColor: NSColor
    var overlayAlpha: CGFloat

    init(connection: Connection,
         from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D,
         color: NSColor, alpha: CGFloat) {
        self.connection = connection
        self.startCoord = start
        self.endCoord = end
        self.strokeColor = color
        self.overlayAlpha = alpha
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude:  (startCoord.latitude  + endCoord.latitude)  / 2,
            longitude: (startCoord.longitude + endCoord.longitude) / 2
        )
    }

    var boundingMapRect: MKMapRect {
        let p1 = MKMapPoint(startCoord), p2 = MKMapPoint(endCoord)
        let minX = min(p1.x, p2.x), maxX = max(p1.x, p2.x)
        let minY = min(p1.y, p2.y), maxY = max(p1.y, p2.y)
        let w = max(maxX - minX, 1), h = max(maxY - minY, 1)
        return MKMapRect(x: minX - w * 0.5, y: minY - h * 0.5, width: w * 2, height: h * 2)
    }
}

// MARK: - City Annotation

/// Endpoint pin for one destination city (aggregated across processes).
final class CityAnnotation: NSObject, MKAnnotation {
    var cityKey = ""
    var topProcess = ""
    var pinColor: NSColor = .systemGray
    dynamic var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D()
    dynamic var title: String?
    dynamic var subtitle: String?
}

// MARK: - Connection Overlay Renderer

/// Draws a quadratic Bézier arc in screen (point) coordinates.
final class ConnectionOverlayRenderer: MKOverlayRenderer {
    private let conn: ConnectionOverlay

    init(_ overlay: ConnectionOverlay) {
        self.conn = overlay
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let p1 = point(for: MKMapPoint(conn.startCoord))
        let p2 = point(for: MKMapPoint(conn.endCoord))
        let ctrl = Self.controlPoint(p1: p1, p2: p2, curvature: 0.15)

        let path = CGMutablePath()
        path.move(to: p1)
        path.addQuadCurve(to: p2, control: ctrl)

        context.setLineWidth(3 / zoomScale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(conn.strokeColor.withAlphaComponent(conn.overlayAlpha).cgColor)
        context.addPath(path)
        context.strokePath()
    }

    static func controlPoint(p1: CGPoint, p2: CGPoint, curvature: CGFloat) -> CGPoint {
        let mx = (p1.x + p2.x) / 2
        let my = (p1.y + p2.y) / 2
        let dx = p2.x - p1.x, dy = p2.y - p1.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return CGPoint(x: mx, y: my) }
        let offset = len * curvature
        return CGPoint(x: mx + (-dy / len) * offset, y: my + (dx / len) * offset)
    }
}

// MARK: - MapView Representable

struct MapViewRepresentable: NSViewRepresentable {
    let connections: [Connection]
    let selectedProcess: String?
    let allConnections: [Connection]
    let processColor: (String) -> String
    let mapProxy: MapViewProxy
    let onSelectProcess: (String) -> Void

    func makeNSView(context: Context) -> MKMapView {
        let mv = MKMapView()
        mv.delegate = context.coordinator
        mv.mapType = .standard
        mv.showsUserLocation = false
        mapProxy.mapView = mv
        context.coordinator.mapProxy = mapProxy
        return mv
    }

    func updateNSView(_ nsView: MKMapView, context: Context) {
        context.coordinator.update(
            mapView: nsView,
            connections: connections,
            selectedProcess: selectedProcess,
            allConnections: allConnections,
            processColor: processColor,
            onSelectProcess: onSelectProcess
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        weak var mapProxy: MapViewProxy?
        private var currentOverlays: [String: ConnectionOverlay] = [:]
        private var currentAnnotations: [String: CityAnnotation] = [:]
        private var lastArcKeys: Set<String> = []
        private var lastCityKeys: Set<String> = []
        private var lastSelectedProcess: String? = nil
        private var localCoordinate = CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
        private var didInit = false
        private weak var mapViewRef: MKMapView?
        private var userInteracted = false
        private var onSelectProcess: ((String) -> Void)?

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            userInteracted = true
        }

        func update(mapView: MKMapView, connections: [Connection], selectedProcess: String?,
                    allConnections: [Connection], processColor: (String) -> String,
                    onSelectProcess: @escaping (String) -> Void) {
            self.onSelectProcess = onSelectProcess

            if !didInit {
                didInit = true
                mapViewRef = mapView
                let region = MKCoordinateRegion(center: localCoordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 80))
                mapView.setRegion(region, animated: false)
                resolveOwnLocation()
            }

            let connsToShow = (selectedProcess == nil) ? allConnections : connections

            // Group arcs by (process, destination city) and pins by city
            var arcSeeds: [String: Connection] = [:]
            var cities: [String: (coord: CLLocationCoordinate2D, title: String, count: Int,
                                  topProcess: String, topCount: Int)] = [:]
            var cityProcessCounts: [String: [String: Int]] = [:]

            for conn in connsToShow {
                guard let geo = conn.geoInfo, conn.remoteIP != "*" else { continue }
                let cityKey = Self.cityKey(for: geo)
                let arcKey = conn.processName + "|" + cityKey
                if arcSeeds[arcKey] == nil { arcSeeds[arcKey] = conn }

                var entry = cities[cityKey] ?? (
                    coord: geo.coordinate,
                    title: Self.cityTitle(for: geo),
                    count: 0,
                    topProcess: conn.processName,
                    topCount: 0
                )
                entry.count += 1

                var counts = cityProcessCounts[cityKey] ?? [:]
                let processCount = (counts[conn.processName] ?? 0) + 1
                counts[conn.processName] = processCount
                cityProcessCounts[cityKey] = counts
                if processCount > entry.topCount {
                    entry.topProcess = conn.processName
                    entry.topCount = processCount
                }
                cities[cityKey] = entry
            }

            let selectionChanged = lastSelectedProcess != selectedProcess
            let arcsChanged = lastArcKeys != Set(arcSeeds.keys)
            let citiesChanged = lastCityKeys != Set(cities.keys)

            guard arcsChanged || citiesChanged || selectionChanged else { return }

            // Arc overlays
            var newMap: [String: ConnectionOverlay] = [:]
            for (arcKey, conn) in arcSeeds {
                guard let geo = conn.geoInfo else { continue }
                let isSelected = selectedProcess == nil || conn.processName == selectedProcess
                let color = NSColor(hex: processColor(conn.processName)) ?? .systemBlue
                let alpha: CGFloat = isSelected ? 0.7 : 0.2

                if let existing = currentOverlays[arcKey] {
                    existing.strokeColor = color
                    existing.overlayAlpha = alpha
                    newMap[arcKey] = existing
                } else {
                    newMap[arcKey] = ConnectionOverlay(
                        connection: conn,
                        from: localCoordinate,
                        to: geo.coordinate,
                        color: color,
                        alpha: alpha
                    )
                }
            }

            for (key, overlay) in currentOverlays where newMap[key] == nil {
                mapView.removeOverlay(overlay)
            }
            let overlaysToAdd = newMap.filter { currentOverlays[$0.key] == nil }.map { $0.value }
            if !overlaysToAdd.isEmpty { mapView.addOverlays(overlaysToAdd) }

            if selectionChanged {
                for overlay in newMap.values {
                    mapView.renderer(for: overlay)?.setNeedsDisplay()
                }
            }

            // City endpoint pins
            var newAnnotations: [String: CityAnnotation] = [:]
            for (cityKey, info) in cities {
                let subtitle = String(format: String(localized: "%d connections · %@", bundle: .module),
                                      info.count, info.topProcess)
                let color = NSColor(hex: processColor(info.topProcess)) ?? .systemGray
                if let existing = currentAnnotations[cityKey] {
                    existing.title = info.title
                    existing.subtitle = subtitle
                    existing.coordinate = info.coord
                    existing.pinColor = color
                    if let marker = mapView.view(for: existing) as? MKMarkerAnnotationView {
                        marker.markerTintColor = color
                    }
                    newAnnotations[cityKey] = existing
                } else {
                    let annotation = CityAnnotation()
                    annotation.cityKey = cityKey
                    annotation.topProcess = info.topProcess
                    annotation.pinColor = color
                    annotation.coordinate = info.coord
                    annotation.title = info.title
                    annotation.subtitle = subtitle
                    newAnnotations[cityKey] = annotation
                }
            }

            for (key, annotation) in currentAnnotations where newAnnotations[key] == nil {
                mapView.removeAnnotation(annotation)
            }
            let annotationsToAdd = newAnnotations.values.filter { currentAnnotations[$0.cityKey] == nil }
            if !annotationsToAdd.isEmpty { mapView.addAnnotations(Array(annotationsToAdd)) }

            currentOverlays = newMap
            currentAnnotations = newAnnotations
            lastArcKeys = Set(arcSeeds.keys)
            lastCityKeys = Set(cities.keys)
            lastSelectedProcess = selectedProcess
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let connOverlay = overlay as? ConnectionOverlay {
                return ConnectionOverlayRenderer(connOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let city = annotation as? CityAnnotation else { return nil }
            let identifier = "CityPin"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: city, reuseIdentifier: identifier)
            view.annotation = city
            view.canShowCallout = true
            view.markerTintColor = city.pinColor
            view.titleVisibility = .adaptive
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let city = view.annotation as? CityAnnotation else { return }
            onSelectProcess?(city.topProcess)
        }

        static func cityKey(for geo: GeoInfo) -> String {
            if let city = geo.city, !city.isEmpty {
                return "\(city)|\(geo.country)"
            }
            return String(format: "%.1f|%.1f", geo.latitude, geo.longitude)
        }

        static func cityTitle(for geo: GeoInfo) -> String {
            if let city = geo.city, !city.isEmpty {
                return "\(city), \(geo.country)"
            }
            return geo.country
        }

        private func resolveOwnLocation() {
            Task { [weak self] in
                guard let geo = await GeoDatabase.shared.lookupOwnLocation() else { return }
                await MainActor.run {
                    guard let self = self else { return }
                    self.localCoordinate = geo.coordinate
                    self.mapProxy?.originCoordinate = geo.coordinate
                    if !self.userInteracted {
                        self.mapProxy?.recenterToOrigin()
                    }
                    self.lastArcKeys = []
                    self.lastCityKeys = []
                    if let mapView = self.mapViewRef {
                        mapView.removeOverlays(mapView.overlays)
                        mapView.removeAnnotations(mapView.annotations)
                        self.currentOverlays = [:]
                        self.currentAnnotations = [:]
                    }
                }
            }
        }
    }
}
