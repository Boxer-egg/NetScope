import Foundation
import MapKit

struct GeoInfo: Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    let city: String?
    let country: String
    let countryCode: String
    let asn: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
