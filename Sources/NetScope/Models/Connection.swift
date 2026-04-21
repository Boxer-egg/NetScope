import Foundation

struct Connection: Identifiable, Equatable, Hashable {
    let id: String
    let pid: Int
    let processName: String
    let localPort: Int
    let remoteIP: String
    let remotePort: Int
    let proto: String
    let state: String
    var geoInfo: GeoInfo?
    var firstSeen: Date
    var lastSeen: Date

    init(pid: Int, processName: String, localPort: Int, remoteIP: String, remotePort: Int, proto: String, state: String) {
        self.id = "\(pid)-\(localPort)-\(remoteIP)-\(remotePort)"
        self.pid = pid
        self.processName = processName
        self.localPort = localPort
        self.remoteIP = remoteIP
        self.remotePort = remotePort
        self.proto = proto
        self.state = state
        self.firstSeen = Date()
        self.lastSeen = Date()
    }
}
