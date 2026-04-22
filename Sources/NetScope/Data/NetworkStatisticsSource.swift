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

    private func value<T>(from obj: AnyObject, selector: String, as type: T.Type) -> T? {
        let sel = NSSelectorFromString(selector)
        guard obj.responds(to: sel) else { return nil }
        return obj.perform(sel)?.takeUnretainedValue() as? T
    }

    private func parseConnectionSnapshot(_ snapshot: AnyObject) -> Connection? {
        let pid = (value(from: snapshot, selector: "pid", as: NSNumber.self))?.intValue ?? 0

        let processName = (value(from: snapshot, selector: "processName", as: String.self))
            ?? (value(from: snapshot, selector: "comm", as: String.self))
            ?? "Unknown"

        let localPort = (value(from: snapshot, selector: "localPort", as: NSNumber.self))?.intValue ?? 0

        let remoteAddress = (value(from: snapshot, selector: "remoteAddress", as: String.self)) ?? ""
        let remotePort = (value(from: snapshot, selector: "remotePort", as: NSNumber.self))?.intValue ?? 0

        let bytesIn = (value(from: snapshot, selector: "bytesIn", as: NSNumber.self))?.int64Value ?? 0
        let bytesOut = (value(from: snapshot, selector: "bytesOut", as: NSNumber.self))?.int64Value ?? 0

        let state = (value(from: snapshot, selector: "state", as: String.self)) ?? "Unknown"

        let proto = (value(from: snapshot, selector: "protocol", as: String.self))
            ?? (value(from: snapshot, selector: "networkProtocol", as: String.self))
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
