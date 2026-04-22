import Foundation
import Combine

@MainActor
class ConnectionStore: ObservableObject {
    @Published var connections: [Connection] = []
    @Published var selectedProcess: String? = nil
    @Published var isLoading = false

    private var connectionMap: [String: Connection] = [:]
    private var processColors: [String: Int] = [:]
    private var colorIndex = 0
    private var queriedIPs: Set<String> = []

    let processColorsList: [String] = [
        "#58A6FF", "#3FB950", "#F78166", "#D2A8FF",
        "#FFA657", "#79C0FF", "#56D364", "#FF7B72",
        "#E3B341", "#A5D6FF", "#FFA198", "#B1F0D4"
    ]

    var processes: [(name: String, pid: Int, count: Int, colorIndex: Int)] {
        let grouped = Dictionary(grouping: connections) { $0.processName }
        return grouped.map { (name, conns) in
            let pid = conns.first?.pid ?? 0
            let colorIdx = processColorIndex(for: name)
            return (name: name, pid: pid, count: conns.count, colorIndex: colorIdx)
        }.sorted { $0.count > $1.count || ($0.count == $1.count && $0.name < $1.name) }
    }

    var filteredConnections: [Connection] {
        if let proc = selectedProcess {
            return connections.filter { $0.processName == proc }
        }
        return connections
    }

    var totalConnectionCount: Int { connections.count }

    // MARK: - Summary Statistics

    var uniqueProcessCount: Int {
        Set(connections.map { $0.processName }).count
    }

    var uniqueHostCount: Int {
        Set(connections.map { $0.remoteIP }).count
    }

    var totalBytesIn: Int64 {
        connections.reduce(0) { $0 + $1.bytesIn }
    }

    var totalBytesOut: Int64 {
        connections.reduce(0) { $0 + $1.bytesOut }
    }

    var connectionsByState: [(state: String, count: Int)] {
        let grouped = Dictionary(grouping: connections) { $0.state }
        return grouped.map { (state, conns) in
            (state: state, count: conns.count)
        }.sorted { $0.count > $1.count }
    }

    var topProcesses: [(name: String, pid: Int, bytesIn: Int64, bytesOut: Int64)] {
        let grouped = Dictionary(grouping: connections) { $0.processName }
        var result: [(name: String, pid: Int, bytesIn: Int64, bytesOut: Int64)] = []
        for (name, conns) in grouped {
            let pid = conns.first?.pid ?? 0
            let bytesIn = conns.reduce(0) { $0 + $1.bytesIn }
            let bytesOut = conns.reduce(0) { $0 + $1.bytesOut }
            result.append((name: name, pid: pid, bytesIn: bytesIn, bytesOut: bytesOut))
        }
        return result.sorted { $0.bytesIn + $0.bytesOut > $1.bytesIn + $1.bytesOut }
    }

    var topHosts: [(host: String, bytesIn: Int64, bytesOut: Int64)] {
        let grouped = Dictionary(grouping: connections) { $0.remoteIP }
        var result: [(host: String, bytesIn: Int64, bytesOut: Int64)] = []
        for (host, conns) in grouped {
            let bytesIn = conns.reduce(0) { $0 + $1.bytesIn }
            let bytesOut = conns.reduce(0) { $0 + $1.bytesOut }
            result.append((host: host, bytesIn: bytesIn, bytesOut: bytesOut))
        }
        return result.sorted { $0.bytesIn + $0.bytesOut > $1.bytesIn + $1.bytesOut }
    }

    func update(with fresh: [Connection]) {
        let now = Date()

        var freshMap = buildSafeMap(from: fresh)
        var added: [Connection] = []

        for (id, mutConn) in freshMap {
            var conn = mutConn
            if let existing = connectionMap[id] {
                conn.firstSeen = existing.firstSeen
                conn.geoInfo = existing.geoInfo
                conn.lastSeen = now

                let deltaIn = conn.bytesIn - existing.bytesIn
                let deltaOut = conn.bytesOut - existing.bytesOut
                conn.bytesIn = deltaIn >= 0 ? deltaIn : conn.bytesIn
                conn.bytesOut = deltaOut >= 0 ? deltaOut : conn.bytesOut

                if conn.geoInfo == nil, !queriedIPs.contains(conn.remoteIP) {
                    added.append(conn)
                    queriedIPs.insert(conn.remoteIP)
                }
            } else {
                conn.firstSeen = now
                conn.lastSeen = now
                if !queriedIPs.contains(conn.remoteIP) {
                    added.append(conn)
                    queriedIPs.insert(conn.remoteIP)
                }
            }
            freshMap[id] = conn
        }

        connections = Array(freshMap.values)
            .sorted { $0.processName < $1.processName || ($0.processName == $1.processName && $0.id < $1.id) }

        connectionMap = buildSafeMap(from: Array(freshMap.values))

        if !added.isEmpty {
            Task { await fetchGeoInfo(for: added) }
        }
    }

    private func buildSafeMap(from conns: [Connection]) -> [String: Connection] {
        return Dictionary(conns.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func fetchGeoInfo(for connections: [Connection]) async {
        // Deduplicate by remoteIP to avoid redundant lookups
        let uniqueIPs = Set(connections.map { $0.remoteIP })
        await withTaskGroup(of: Void.self) { group in
            for ip in uniqueIPs {
                group.addTask {
                    let geo = await GeoDatabase.shared.lookup(ip: ip)
                    if let geo = geo {
                        await MainActor.run { self.updateGeoInfoForIP(ip: ip, geo: geo) }
                    }
                }
            }
        }
    }

    private func updateGeoInfoForIP(ip: String, geo: GeoInfo) {
        for (id, var conn) in connectionMap {
            if conn.remoteIP == ip {
                conn.geoInfo = geo
                connectionMap[id] = conn
                if let idx = connections.firstIndex(where: { $0.id == id }) {
                    connections[idx].geoInfo = geo
                }
            }
        }
    }

    func colorForProcess(_ name: String) -> String {
        let idx = processColorIndex(for: name)
        return processColorsList[idx % processColorsList.count]
    }

    private func processColorIndex(for name: String) -> Int {
        if let idx = processColors[name] { return idx }
        let idx = colorIndex
        processColors[name] = idx
        colorIndex = (colorIndex + 1) % processColorsList.count
        return idx
    }

    func selectProcess(_ name: String?) { selectedProcess = name }
}
