import Foundation
import Combine

@MainActor
class ConnectionStore: ObservableObject {
    @Published var connections: [Connection] = []
    @Published var selectedProcess: String? = nil // "All" = nil
    @Published var isLoading = false

    private var connectionMap: [String: Connection] = [:]
    private var processColors: [String: Int] = [:]
    private var colorIndex = 0

    let processColorsList: [String] = [
        "#58A6FF", "#3FB950", "#F78166", "#D2A8FF",
        "#FFA657", "#79C0FF", "#56D364", "#FF7B72",
        "#E3B341", "#A5D6FF", "#FFA198", "#B1F0D4"
    ]

    var processes: [(name: String, pid: Int, count: Int, colorIndex: Int)] {
        let grouped = Dictionary(grouping: connections) { $0.processName }
        return grouped.map { (name, conns) in
            let pids = Set(conns.map { $0.pid })
            let pid = pids.first ?? 0
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

    func colorForProcess(_ name: String) -> String {
        let idx = processColorIndex(for: name)
        return processColorsList[idx % processColorsList.count]
    }

    private func processColorIndex(for name: String) -> Int {
        if let idx = processColors[name] {
            return idx
        }
        let idx = colorIndex
        processColors[name] = idx
        colorIndex = (colorIndex + 1) % processColorsList.count
        return idx
    }

    func update(with fresh: [Connection]) {
        let now = Date()
        var freshMap: [String: Connection] = [:]
        var added: [Connection] = []

        for mutConn in fresh {
            var conn = mutConn
            if let existing = connectionMap[conn.id] {
                // Keep existing firstSeen and update lastSeen
                conn.firstSeen = existing.firstSeen
                conn.geoInfo = existing.geoInfo
                conn.lastSeen = now

                // If geoInfo was nil previously (e.g. failed lookup), retry now
                if conn.geoInfo == nil {
                    added.append(conn)
                }
            } else {
                // This is a truly new connection
                conn.firstSeen = now
                conn.lastSeen = now
                added.append(conn)
            }
            freshMap[conn.id] = conn
        }

        connectionMap = freshMap

        // Update the published connections list
        // Note: Filtered connections for the UI are computed from this
        connections = Array(freshMap.values)
            .sorted { $0.processName < $1.processName || ($0.processName == $1.processName && $0.id < $1.id) }

        // Fetch geo info only for truly new connections
        if !added.isEmpty {
            Task {
                await fetchGeoInfo(for: added)
            }
        }
    }

    private func fetchGeoInfo(for connections: [Connection]) async {
        await withTaskGroup(of: Void.self) { group in
            for conn in connections {
                group.addTask {
                    let geo = await GeoDatabase.shared.lookup(ip: conn.remoteIP)
                    if let geo = geo {
                        await MainActor.run {
                            self.updateGeoInfo(id: conn.id, geo: geo)
                        }
                    }
                }
            }
        }
    }

    private func updateGeoInfo(id: String, geo: GeoInfo) {
        if var conn = connectionMap[id] {
            conn.geoInfo = geo
            connectionMap[id] = conn
            if let idx = connections.firstIndex(where: { $0.id == id }) {
                connections[idx].geoInfo = geo
            }
        }
    }

    func selectProcess(_ name: String?) {
        selectedProcess = name
    }
}
