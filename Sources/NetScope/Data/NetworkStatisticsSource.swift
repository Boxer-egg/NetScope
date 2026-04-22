import Foundation

class NetworkStatisticsSource: ConnectionSource {
    private var timer: Timer?
    var onUpdate: (([Connection]) -> Void)?

    var displayName: String { "NetworkStatistics" }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.tolerance = 0.2
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let connections = fetchConnections()
        onUpdate?(connections)
    }

    // MARK: - Runtime bridging to NetworkStatistics.framework

    private func fetchConnections() -> [Connection] {
        guard let snapshotClass = NSClassFromString("NWSSnapshot"),
              snapshotClass.responds(to: NSSelectorFromString("snapshot")),
              let snapshot = (snapshotClass as AnyObject).perform(NSSelectorFromString("snapshot"))?.takeUnretainedValue() else {
            return []
        }

        guard let protocols = (snapshot as AnyObject).perform(NSSelectorFromString("protocols"))?.takeUnretainedValue() as? [AnyObject] else {
            return []
        }

        var connections: [Connection] = []

        for proto in protocols {
            guard let protoConns = (proto as AnyObject).perform(NSSelectorFromString("connections"))?.takeUnretainedValue() as? [AnyObject] else {
                continue
            }

            for conn in protoConns {
                if let connection = parseConnectionSnapshot(conn) {
                    connections.append(connection)
                }
            }
        }

        return connections
    }

    private func parseConnectionSnapshot(_ snapshot: AnyObject) -> Connection? {
        let pid = (snapshot.perform(NSSelectorFromString("pid"))?.takeUnretainedValue() as? NSNumber)?.intValue ?? 0

        let processName = (snapshot.perform(NSSelectorFromString("processName"))?.takeUnretainedValue() as? String)
            ?? (snapshot.perform(NSSelectorFromString("comm"))?.takeUnretainedValue() as? String)
            ?? "Unknown"

        let localAddress = (snapshot.perform(NSSelectorFromString("localAddress"))?.takeUnretainedValue() as? String) ?? ""
        let localPort = (snapshot.perform(NSSelectorFromString("localPort"))?.takeUnretainedValue() as? NSNumber)?.intValue ?? 0

        let remoteAddress = (snapshot.perform(NSSelectorFromString("remoteAddress"))?.takeUnretainedValue() as? String) ?? ""
        let remotePort = (snapshot.perform(NSSelectorFromString("remotePort"))?.takeUnretainedValue() as? NSNumber)?.intValue ?? 0

        let bytesIn = (snapshot.perform(NSSelectorFromString("bytesIn"))?.takeUnretainedValue() as? NSNumber)?.int64Value ?? 0
        let bytesOut = (snapshot.perform(NSSelectorFromString("bytesOut"))?.takeUnretainedValue() as? NSNumber)?.int64Value ?? 0

        let state = (snapshot.perform(NSSelectorFromString("state"))?.takeUnretainedValue() as? String) ?? "Unknown"

        let proto = (snapshot.perform(NSSelectorFromString("protocol"))?.takeUnretainedValue() as? String)
            ?? (snapshot.perform(NSSelectorFromString("networkProtocol"))?.takeUnretainedValue() as? String)
            ?? "TCP"

        return Connection(
            pid: pid,
            processName: processName,
            localPort: localPort,
            remoteIP: remoteAddress,
            remotePort: remotePort,
            proto: proto.uppercased(),
            state: state,
            bytesIn: bytesIn,
            bytesOut: bytesOut
        )
    }
}
