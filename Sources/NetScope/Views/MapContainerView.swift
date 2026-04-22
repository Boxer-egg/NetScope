import SwiftUI
import MapKit
import AppKit
import CoreLocation

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

    class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
        weak var mapProxy: MapViewProxy?
        private var currentOverlays: [String: MKPolyline] = [:]
        private var overlayColors: [MKPolyline: NSColor] = [:]
        private var overlayAlphas: [MKPolyline: CGFloat] = [:]
        private var localCoordinate = CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
        private let locationManager = CLLocationManager()
        private var didInit = false

        override init() {
            super.init()
            locationManager.delegate = self
        }

        func update(mapView: MKMapView, connections: [Connection], selectedProcess: String?, allConnections: [Connection], processColor: (String) -> String) {
            if !didInit {
                didInit = true
                locationManager.requestAlwaysAuthorization()
                let region = MKCoordinateRegion(center: localCoordinate, span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 80))
                mapView.setRegion(region, animated: false)
            }

            var newOverlaysMap: [String: (MKPolyline, NSColor, CGFloat)] = [:]
            let connsToShow = (selectedProcess == nil) ? allConnections : connections

            for conn in connsToShow {
                guard let geo = conn.geoInfo, conn.remoteIP != "*" else { continue }
                let isSelected = selectedProcess == nil || conn.processName == selectedProcess
                let color = NSColor(hex: processColor(conn.processName)) ?? .systemBlue
                let alpha: CGFloat = isSelected ? 0.7 : 0.2

                // 使用自定义贝塞尔曲线，曲率更小
                let points = curvedCoordinates(from: localCoordinate, to: geo.coordinate, segments: 40)
                let polyline = MKPolyline(coordinates: points, count: points.count)
                newOverlaysMap[conn.id] = (polyline, color, alpha)
            }

            // Diff overlays
            let toRemove = currentOverlays.keys.filter { newOverlaysMap[$0] == nil }
            for id in toRemove {
                if let ov = currentOverlays[id] {
                    mapView.removeOverlay(ov)
                    overlayColors.removeValue(forKey: ov)
                    overlayAlphas.removeValue(forKey: ov)
                }
                currentOverlays.removeValue(forKey: id)
            }

            for (id, data) in newOverlaysMap {
                if currentOverlays[id] == nil {
                    // Set color cache BEFORE adding overlay to avoid race with rendererFor
                    overlayColors[data.0] = data.1
                    overlayAlphas[data.0] = data.2
                    mapView.addOverlay(data.0)
                    currentOverlays[id] = data.0
                } else {
                    // Update alpha if selection changed
                    if let existing = currentOverlays[id] {
                        overlayAlphas[existing] = data.2
                        // Force renderer refresh by removing and re-adding
                        mapView.removeOverlay(existing)
                        overlayColors.removeValue(forKey: existing)
                        overlayAlphas.removeValue(forKey: existing)
                        overlayColors[data.0] = data.1
                        overlayAlphas[data.0] = data.2
                        mapView.addOverlay(data.0)
                        currentOverlays[id] = data.0
                    }
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = overlayColors[polyline] ?? .systemBlue
                renderer.lineWidth = 3
                renderer.alpha = overlayAlphas[polyline] ?? 0.6
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let loc = locations.last { localCoordinate = loc.coordinate; mapProxy?.originCoordinate = loc.coordinate }
        }
        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            if manager.authorizationStatus == .authorizedAlways { manager.requestLocation() }
        }

        // MARK: - Curved Path Generation

        private func curvedCoordinates(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, segments: Int = 40) -> [CLLocationCoordinate2D] {
            // 计算中点
            let midLat = (start.latitude + end.latitude) / 2
            let midLon = (start.longitude + end.longitude) / 2

            // 计算方向向量
            let dLat = end.latitude - start.latitude
            let dLon = end.longitude - start.longitude
            let distance = sqrt(dLat * dLat + dLon * dLon)

            // 垂直方向（逆时针旋转90度）并归一化
            var perpLat = -dLon
            var perpLon = dLat
            let perpLen = sqrt(perpLat * perpLat + perpLon * perpLon)
            if perpLen > 0 {
                perpLat /= perpLen
                perpLon /= perpLen
            }

            // 控制点 = 中点 + 垂直偏移（直线距离的15%，曲率更小）
            let offset = distance * 0.15
            let controlLat = midLat + perpLat * offset
            let controlLon = midLon + perpLon * offset
            let controlPoint = CLLocationCoordinate2D(latitude: controlLat, longitude: controlLon)

            // 二次贝塞尔曲线采样
            var points: [CLLocationCoordinate2D] = []
            for i in 0...segments {
                let t = Double(i) / Double(segments)
                let mt = 1.0 - t
                let lat = mt * mt * start.latitude + 2.0 * mt * t * controlPoint.latitude + t * t * end.latitude
                let lon = mt * mt * start.longitude + 2.0 * mt * t * controlPoint.longitude + t * t * end.longitude
                points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
            return points
        }
    }
}
