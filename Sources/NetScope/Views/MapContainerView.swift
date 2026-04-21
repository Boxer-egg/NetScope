import SwiftUI
import MapKit
import AppKit
import CoreLocation

// MARK: - Arc Overlay

class ArcOverlay: NSObject, MKOverlay {
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    let color: NSColor
    let connectionID: String
    let isSelected: Bool
    let isTraceroute: Bool

    init(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D, color: NSColor, connectionID: String, isSelected: Bool, isTraceroute: Bool = false) {
        self.start = start
        self.end = end
        self.color = color
        self.connectionID = connectionID
        self.isSelected = isSelected
        self.isTraceroute = isTraceroute

        // Calculate bounding rect
        let startPoint = MKMapPoint(start)
        let endPoint = MKMapPoint(end)
        let minX = min(startPoint.x, endPoint.x)
        let minY = min(startPoint.y, endPoint.y)
        let maxX = max(startPoint.x, endPoint.x)
        let maxY = max(startPoint.y, endPoint.y)
        let width = maxX - minX
        let height = maxY - minY
        self.boundingMapRect = MKMapRect(x: minX, y: minY, width: width, height: height).insetBy(dx: -width * 0.2, dy: -height * 0.2)
        self.coordinate = CLLocationCoordinate2D(latitude: (start.latitude + end.latitude) / 2, longitude: (start.longitude + end.longitude) / 2)
    }
}

class ArcOverlayRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let arc = overlay as? ArcOverlay else { return }

        let startPt = point(for: MKMapPoint(arc.start))
        let endPt = point(for: MKMapPoint(arc.end))

        // Control point: midpoint shifted upward (north)
        let midX = (startPt.x + endPt.x) / 2
        let midY = (startPt.y + endPt.y) / 2
        let offset = abs(endPt.x - startPt.x) * 0.3
        let ctrlPt = CGPoint(x: midX, y: midY - offset)

        let path = CGMutablePath()
        path.move(to: startPt)
        path.addQuadCurve(to: endPt, control: ctrlPt)

        context.addPath(path)

        let alpha: CGFloat = arc.isTraceroute ? 0.9 : (arc.isSelected ? 0.85 : 0.2)
        context.setStrokeColor(arc.color.withAlphaComponent(alpha).cgColor)
        context.setLineWidth(arc.isTraceroute ? 2.0 / zoomScale : (arc.isSelected ? 2.5 / zoomScale : 1.5 / zoomScale))

        if arc.isTraceroute {
            context.setLineDash(phase: 0, lengths: [4 / zoomScale, 4 / zoomScale])
        }

        context.strokePath()
    }
}

// MARK: - IP Annotation

class IPAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let connectionID: String
    let color: NSColor

    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, connectionID: String, color: NSColor) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.connectionID = connectionID
        self.color = color
        super.init()
    }
}

class IPAnnotationView: MKAnnotationView {
    override var annotation: MKAnnotation? {
        didSet {
            if let ipAnn = annotation as? IPAnnotation {
                setupView(color: ipAnn.color)
            }
        }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        if let ipAnn = annotation as? IPAnnotation {
            setupView(color: ipAnn.color)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    private func setupView(color: NSColor) {
        frame = CGRect(x: 0, y: 0, width: 12, height: 12)
        layer?.backgroundColor = color.cgColor
        layer?.cornerRadius = 6
        layer?.borderWidth = 1.5
        layer?.borderColor = NSColor.white.cgColor
        canShowCallout = true
    }
}

// MARK: - Origin Annotation (Pulsing)

class OriginAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    let title: String? = "YOU"

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}

class OriginAnnotationView: MKAnnotationView {
    private var pulseLayer: CAShapeLayer?

    override var annotation: MKAnnotation? {
        didSet { setupView() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
        startPulse()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        canShowCallout = false

        // Center dot
        let dotLayer = CAShapeLayer()
        dotLayer.path = CGPath(ellipseIn: CGRect(x: 6, y: 6, width: 12, height: 12), transform: nil)
        dotLayer.fillColor = NSColor.systemBlue.cgColor
        layer?.addSublayer(dotLayer)
    }

    private func startPulse() {
        let pulse = CAShapeLayer()
        pulse.path = CGPath(ellipseIn: CGRect(x: 2, y: 2, width: 20, height: 20), transform: nil)
        pulse.fillColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
        pulse.opacity = 0.6
        layer?.insertSublayer(pulse, at: 0)
        self.pulseLayer = pulse

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 1.0
        scaleAnim.toValue = 1.5
        scaleAnim.duration = 0.8

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 0.6
        opacityAnim.toValue = 0.0
        opacityAnim.duration = 0.8

        let group = CAAnimationGroup()
        group.animations = [scaleAnim, opacityAnim]
        group.duration = 0.8
        group.repeatCount = .infinity
        group.autoreverses = false

        pulse.add(group, forKey: "pulse")
    }
}

// MARK: - Map View Proxy

@MainActor
class MapViewProxy: ObservableObject {
    weak var mapView: MKMapView?
    var originCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)

    func recenterToOrigin() {
        let region = MKCoordinateRegion(
            center: originCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
        )
        mapView?.setRegion(region, animated: true)
    }

    func zoomIn() {
        guard let mapView = mapView else { return }
        var region = mapView.region
        region.span.latitudeDelta = max(region.span.latitudeDelta * 0.5, 0.01)
        region.span.longitudeDelta = max(region.span.longitudeDelta * 0.5, 0.01)
        mapView.setRegion(region, animated: true)
    }

    func zoomOut() {
        guard let mapView = mapView else { return }
        var region = mapView.region
        region.span.latitudeDelta = min(region.span.latitudeDelta * 2, 180)
        region.span.longitudeDelta = min(region.span.longitudeDelta * 2, 360)
        mapView.setRegion(region, animated: true)
    }
}

// MARK: - Map View

struct MapContainerView: View {
    @EnvironmentObject var connectionStore: ConnectionStore
    @EnvironmentObject var tracerouteStore: TracerouteStore
    @StateObject private var mapProxy = MapViewProxy()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MapViewRepresentable(
                connections: connectionStore.filteredConnections,
                selectedProcess: connectionStore.selectedProcess,
                allConnections: connectionStore.connections,
                processColor: { connectionStore.colorForProcess($0) },
                tracerouteHops: tracerouteStore.hops,
                mapProxy: mapProxy
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 6) {
                MapButton(systemName: "plus") { mapProxy.zoomIn() }
                MapButton(systemName: "minus") { mapProxy.zoomOut() }
                MapButton(systemName: "location.fill") { mapProxy.recenterToOrigin() }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
        }
    }
}

struct MapButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }
}

struct MapViewRepresentable: NSViewRepresentable {
    let connections: [Connection]
    let selectedProcess: String?
    let allConnections: [Connection]
    let processColor: (String) -> String
    let tracerouteHops: [TracerouteHop]
    let mapProxy: MapViewProxy

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false

        mapProxy.mapView = mapView
        context.coordinator.mapProxy = mapProxy

        // Set initial region (world view)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 30, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 150, longitudeDelta: 360)
        )
        mapView.setRegion(region, animated: false)

        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        context.coordinator.update(
            mapView: mapView,
            connections: connections,
            selectedProcess: selectedProcess,
            allConnections: allConnections,
            processColor: processColor,
            tracerouteHops: tracerouteHops
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
        private var currentOverlays: [String: ArcOverlay] = [:]
        private var currentAnnotations: [String: IPAnnotation] = [:]
        private var originAnnotation: OriginAnnotation?
        private var tracerouteOverlays: [ArcOverlay] = []
        private var localCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4) // Default: Beijing
        private var hasSetInitialRegion = false
        weak var mapProxy: MapViewProxy?

        private let locationManager = CLLocationManager()
        private var didRequestLocation = false

        override init() {
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        }

        func update(
            mapView: MKMapView,
            connections: [Connection],
            selectedProcess: String?,
            allConnections: [Connection],
            processColor: (String) -> String,
            tracerouteHops: [TracerouteHop]
        ) {
            // Request location once
            if !didRequestLocation {
                didRequestLocation = true
                let status = locationManager.authorizationStatus
                if status == .notDetermined {
                    locationManager.requestWhenInUseAuthorization()
                } else if status == .authorizedAlways {
                    locationManager.requestLocation()
                } else {
                    // Permission denied — fall back to IP-based location
                    Task {
                        await resolveOwnLocationViaIP(mapView: mapView)
                    }
                }
            }

            // Setup origin annotation and center map
            if originAnnotation == nil {
                let ann = OriginAnnotation(coordinate: localCoordinate)
                originAnnotation = ann
                mapView.addAnnotation(ann)

                if !hasSetInitialRegion {
                    hasSetInitialRegion = true
                    let region = MKCoordinateRegion(
                        center: localCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
                    )
                    mapView.setRegion(region, animated: false)
                }
            }

            // Build new overlays and annotations
            var newOverlays: [String: ArcOverlay] = [:]
            var newAnnotations: [String: IPAnnotation] = [:]

            let connectionsToShow = selectedProcess == nil ? allConnections : connections

            for conn in connectionsToShow {
                guard let geo = conn.geoInfo else { continue }

                let isSelected = selectedProcess == nil || conn.processName == selectedProcess
                let colorStr = processColor(conn.processName)
                let nsColor = NSColor(hex: colorStr) ?? .systemBlue

                let overlay = ArcOverlay(
                    start: localCoordinate,
                    end: geo.coordinate,
                    color: nsColor,
                    connectionID: conn.id,
                    isSelected: isSelected
                )
                newOverlays[conn.id] = overlay

                let annotation = IPAnnotation(
                    coordinate: geo.coordinate,
                    title: conn.remoteIP,
                    subtitle: "\(geo.city ?? "") · \(geo.country) · :\(conn.remotePort)",
                    connectionID: conn.id,
                    color: nsColor
                )
                newAnnotations[conn.id] = annotation
            }

            // Diff and update overlays
            let toRemoveOverlays = currentOverlays.keys.filter { newOverlays[$0] == nil }
            let toAddOverlays = newOverlays.keys.filter { currentOverlays[$0] == nil }

            for key in toRemoveOverlays {
                if let overlay = currentOverlays[key] {
                    mapView.removeOverlay(overlay)
                }
            }
            for key in toAddOverlays {
                if let overlay = newOverlays[key] {
                    mapView.addOverlay(overlay)
                }
            }

            // Diff and update annotations
            let toRemoveAnnotations = currentAnnotations.keys.filter { newAnnotations[$0] == nil }
            let toAddAnnotations = newAnnotations.keys.filter { currentAnnotations[$0] == nil }

            for key in toRemoveAnnotations {
                if let ann = currentAnnotations[key] {
                    mapView.removeAnnotation(ann)
                }
            }
            for key in toAddAnnotations {
                if let ann = newAnnotations[key] {
                    mapView.addAnnotation(ann)
                }
            }

            currentOverlays = newOverlays
            currentAnnotations = newAnnotations

            // Update traceroute overlays
            for overlay in tracerouteOverlays {
                mapView.removeOverlay(overlay)
            }
            tracerouteOverlays = []

            var prevCoord = localCoordinate
            for hop in tracerouteHops {
                guard let geo = hop.geoInfo else { continue }
                let overlay = ArcOverlay(
                    start: prevCoord,
                    end: geo.coordinate,
                    color: NSColor(hex: "#E3B341") ?? .orange,
                    connectionID: "traceroute-\(hop.id)",
                    isSelected: true,
                    isTraceroute: true
                )
                tracerouteOverlays.append(overlay)
                mapView.addOverlay(overlay)
                prevCoord = geo.coordinate
            }
        }

        // MARK: - CLLocationManagerDelegate

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            let coord = location.coordinate
            self.localCoordinate = coord
            self.mapProxy?.originCoordinate = coord

            if let ann = self.originAnnotation {
                ann.coordinate = coord
            }

            if let mapView = self.mapProxy?.mapView {
                let region = MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
                )
                mapView.setRegion(region, animated: true)
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("[CoreLocation] Failed: \(error.localizedDescription)")
            // Fall back to IP-based location
            Task {
                await resolveOwnLocationViaIP(mapView: self.mapProxy?.mapView)
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            let status = manager.authorizationStatus
            if status == .authorizedAlways {
                manager.requestLocation()
            } else if status == .denied || status == .restricted {
                Task {
                    await resolveOwnLocationViaIP(mapView: self.mapProxy?.mapView)
                }
            }
        }

        // MARK: - IP Fallback

        private func resolveOwnLocationViaIP(mapView: MKMapView?) async {
            do {
                let (data, _) = try await URLSession.shared.data(from: URL(string: "https://api.ipify.org?format=json")!)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ip = json["ip"] as? String {
                    if let geo = await GeoDatabase.shared.lookup(ip: ip) {
                        await MainActor.run {
                            self.localCoordinate = geo.coordinate
                            self.mapProxy?.originCoordinate = geo.coordinate
                            if let ann = self.originAnnotation {
                                ann.coordinate = geo.coordinate
                            }
                            if let mapView = mapView {
                                let region = MKCoordinateRegion(
                                    center: geo.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
                                )
                                mapView.setRegion(region, animated: true)
                            }
                        }
                    }
                }
            } catch {
                // Keep default location if lookup fails
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let arc = overlay as? ArcOverlay {
                return ArcOverlayRenderer(overlay: arc)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is OriginAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "origin") as? OriginAnnotationView
                    ?? OriginAnnotationView(annotation: annotation, reuseIdentifier: "origin")
                view.annotation = annotation
                return view
            }
            if annotation is IPAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "ip") as? IPAnnotationView
                    ?? IPAnnotationView(annotation: annotation, reuseIdentifier: "ip")
                view.annotation = annotation
                return view
            }
            return nil
        }
    }
}

// MARK: - NSColor Hex Extension

extension NSColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
