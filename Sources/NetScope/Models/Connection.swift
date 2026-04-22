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

    var bytesIn: Int64
    var bytesOut: Int64

    init(pid: Int, processName: String, localPort: Int, remoteIP: String, remotePort: Int, proto: String, state: String, bytesIn: Int64 = 0, bytesOut: Int64 = 0) {
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

extension NSColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: return nil
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
