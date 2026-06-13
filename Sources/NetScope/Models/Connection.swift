import Foundation
import AppKit

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

    var rawBytesIn: Int64
    var rawBytesOut: Int64
    var bytesIn: Int64
    var bytesOut: Int64

    init(pid: Int, processName: String, localPort: Int, remoteIP: String, remotePort: Int, proto: String, state: String, bytesIn: Int64 = 0, bytesOut: Int64 = 0) {
        self.id = "\(pid)-\(proto)-\(localPort)-\(remoteIP)-\(remotePort)"
        self.pid = pid
        self.processName = processName
        self.localPort = localPort
        self.remoteIP = remoteIP
        self.remotePort = remotePort
        self.proto = proto
        self.state = state
        self.firstSeen = Date()
        self.lastSeen = Date()
        self.rawBytesIn = bytesIn
        self.rawBytesOut = bytesOut
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }

    static func formatRate(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 0.1 { return "0 B/s" }
        else if kb < 1024.0 { return String(format: "%.1f KB/s", kb) }
        else { return String(format: "%.1f MB/s", kb / 1024.0) }
    }
}
