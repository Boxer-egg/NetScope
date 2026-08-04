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
                mapProxy: mapProxy
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

/// One connection arc. The curve is drawn in screen space by ConnectionOverlayRenderer.
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
            processColor: processColor
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        weak var mapProxy: MapViewProxy?
        private var currentOverlays: [String: ConnectionOverlay] = [:]
        private var lastConnectionIDs: Set<String> = []
        private var lastSelectedProcess: String? = nil
        private var localCoordinate = CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
        private var didInit = false
        private weak var mapViewRef: MKMapView?

        func update(mapView: MKMapView, connections: [Connection], selectedProcess: String?,
                    allConnections: [Connection], processColor: (String) -> String) {
            if !didInit {
                didInit = true
                mapViewRef = mapView
                let region = MKCoordinateRegion(center: localCoordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 80))
                mapView.setRegion(region, animated: false)
                resolveOwnLocation()
            }

            let connsToShow = (selectedProcess == nil) ? allConnections : connections
            let visibleIDs = Set(connsToShow.compactMap { $0.geoInfo != nil ? $0.id : nil })
            let selectionChanged = lastSelectedProcess != selectedProcess
            let connectionsChanged = lastConnectionIDs != visibleIDs

            guard connectionsChanged || selectionChanged else { return }

            var newMap: [String: ConnectionOverlay] = [:]

            for conn in connsToShow {
                guard let geo = conn.geoInfo, conn.remoteIP != "*" else { continue }
                let isSelected = selectedProcess == nil || conn.processName == selectedProcess
                let color = NSColor(hex: processColor(conn.processName)) ?? .systemBlue
                let alpha: CGFloat = isSelected ? 0.7 : 0.2

                if let existing = currentOverlays[conn.id] {
                    existing.strokeColor = color
                    existing.overlayAlpha = alpha
                    newMap[conn.id] = existing
                } else {
                    newMap[conn.id] = ConnectionOverlay(
                        connection: conn,
                        from: localCoordinate,
                        to: geo.coordinate,
                        color: color,
                        alpha: alpha
                    )
                }
            }

            for (id, ov) in currentOverlays where newMap[id] == nil {
                mapView.removeOverlay(ov)
            }

            let toAdd = newMap.values.filter { currentOverlays[$0.connection.id] == nil }
            if !toAdd.isEmpty { mapView.addOverlays(Array(toAdd)) }

            if selectionChanged {
                for ov in newMap.values {
                    mapView.renderer(for: ov)?.setNeedsDisplay()
                }
            }

            currentOverlays = newMap
            lastConnectionIDs = visibleIDs
            lastSelectedProcess = selectedProcess
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let connOverlay = overlay as? ConnectionOverlay {
                return ConnectionOverlayRenderer(connOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        private func resolveOwnLocation() {
            Task { [weak self] in
                guard let geo = await GeoDatabase.shared.lookupOwnLocation() else { return }
                await MainActor.run {
                    guard let self = self else { return }
                    self.localCoordinate = geo.coordinate
                    self.mapProxy?.originCoordinate = geo.coordinate
                    self.mapProxy?.recenterToOrigin()
                    self.lastConnectionIDs = []
                    if let mapView = self.mapViewRef {
                        let overlays = mapView.overlays
                        mapView.removeOverlays(overlays)
                        self.currentOverlays = [:]
                    }
                }
            }
        }
    }
}
