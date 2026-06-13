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

    // MARK: - Cached aggregates (recomputed once per update)

    private(set) var processes: [(name: String, pid: Int, count: Int, colorIndex: Int)] = []
    private(set) var processTraffic: [String: (bytesIn: Int64, bytesOut: Int64)] = [:]
    private(set) var uniqueProcessCount: Int = 0
    private(set) var uniqueHostCount: Int = 0
    private(set) var totalBytesIn: Int64 = 0
    private(set) var totalBytesOut: Int64 = 0
    private(set) var connectionsByState: [(state: String, count: Int)] = []
    private(set) var topProcesses: [(name: String, pid: Int, bytesIn: Int64, bytesOut: Int64)] = []
    private(set) var topHosts: [(host: String, bytesIn: Int64, bytesOut: Int64)] = []

    var filteredConnections: [Connection] {
        if let proc = selectedProcess {
            return connections.filter { $0.processName == proc }
        }
        return connections
    }

    var totalConnectionCount: Int { connections.count }

    private func recomputeAggregates() {
        var byProcess: [String: (pid: Int, count: Int, bytesIn: Int64, bytesOut: Int64)] = [:]
        var byHost: [String: (bytesIn: Int64, bytesOut: Int64)] = [:]
        var byState: [String: Int] = [:]
        var totalIn: Int64 = 0
        var totalOut: Int64 = 0
        var processSet = Set<String>()
        var hostSet = Set<String>()

        for conn in connections {
            processSet.insert(conn.processName)
            hostSet.insert(conn.remoteIP)
            totalIn += conn.bytesIn
            totalOut += conn.bytesOut

            if var entry = byProcess[conn.processName] {
                entry.count += 1
                entry.bytesIn += conn.bytesIn
                entry.bytesOut += conn.bytesOut
                byProcess[conn.processName] = entry
            } else {
                byProcess[conn.processName] = (pid: conn.pid, count: 1, bytesIn: conn.bytesIn, bytesOut: conn.bytesOut)
            }

            if var h = byHost[conn.remoteIP] {
                h.bytesIn += conn.bytesIn
                h.bytesOut += conn.bytesOut
                byHost[conn.remoteIP] = h
            } else {
                byHost[conn.remoteIP] = (conn.bytesIn, conn.bytesOut)
            }

            byState[conn.state, default: 0] += 1
        }

        uniqueProcessCount = processSet.count
        uniqueHostCount = hostSet.count
        totalBytesIn = totalIn
        totalBytesOut = totalOut

        processes = byProcess.map { (name, v) in
            (name: name, pid: v.pid, count: v.count, colorIndex: processColorIndex(for: name))
        }.sorted { $0.count > $1.count || ($0.count == $1.count && $0.name < $1.name) }

        processTraffic = byProcess.mapValues { (bytesIn: $0.bytesIn, bytesOut: $0.bytesOut) }

        connectionsByState = byState.map { (state: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        topProcesses = byProcess.map { (name, v) in
            (name: name, pid: v.pid, bytesIn: v.bytesIn, bytesOut: v.bytesOut)
        }.sorted { $0.bytesIn + $0.bytesOut > $1.bytesIn + $1.bytesOut }

        topHosts = byHost.map { (host: $0.key, bytesIn: $0.value.bytesIn, bytesOut: $0.value.bytesOut) }
            .sorted { $0.bytesIn + $0.bytesOut > $1.bytesIn + $1.bytesOut }
    }

    func reset() {
        connections = []
        connectionMap = [:]
        queriedIPs = []
        selectedProcess = nil
        recomputeAggregates()
        // Keep processColors and colorIndex to maintain color consistency across switches
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

                // Calculate delta from raw cumulative values
                let deltaIn = conn.rawBytesIn - existing.rawBytesIn
                let deltaOut = conn.rawBytesOut - existing.rawBytesOut
                conn.bytesIn = deltaIn >= 0 ? deltaIn : 0
                conn.bytesOut = deltaOut >= 0 ? deltaOut : 0

                if conn.geoInfo == nil, !queriedIPs.contains(conn.remoteIP) {
                    added.append(conn)
                    queriedIPs.insert(conn.remoteIP)
                }
            } else {
                conn.firstSeen = now
                conn.lastSeen = now
                // First appearance: show the initial raw value as the first interval's traffic
                conn.bytesIn = conn.rawBytesIn
                conn.bytesOut = conn.rawBytesOut
                if !queriedIPs.contains(conn.remoteIP) {
                    added.append(conn)
                    queriedIPs.insert(conn.remoteIP)
                }
            }
            freshMap[id] = conn
        }

        connections = Array(freshMap.values)
            .sorted { $0.processName < $1.processName || ($0.processName == $1.processName && $0.id < $1.id) }

        connectionMap = freshMap
        recomputeAggregates()

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
