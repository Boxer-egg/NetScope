import Foundation

struct TracerouteHop: Identifiable, Equatable, Hashable {
    let id: Int
    let ip: String?
    let rtt: Double?
    var geoInfo: GeoInfo?

    var isTimeout: Bool { ip == nil }
}
