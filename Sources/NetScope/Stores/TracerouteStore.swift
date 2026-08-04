import Foundation
import Combine

@MainActor
class TracerouteStore: ObservableObject {
    @Published var hops: [TracerouteHop] = []
    @Published var isRunning = false
    @Published var selectedConnectionID: String? = nil
    @Published var targetIP: String = ""
    @Published var errorMessage: String? = nil

    private var selectedConnection: Connection?
    private var runner = TracerouteRunner()
    private var task: Task<Void, Never>?

    func startTraceroute(for connection: Connection) {
        // Cancel existing
        cancel()

        selectedConnection = connection
        selectedConnectionID = connection.id
        targetIP = connection.remoteIP
        hops = []
        isRunning = true
        errorMessage = nil

        task = Task {
            let stream = await runner.run(target: connection.remoteIP)
            for await hop in stream {
                guard !Task.isCancelled else { break }
                self.hops.append(hop)

                // Fetch geo info for hop
                if let ip = hop.ip {
                    let geo = await GeoDatabase.shared.lookup(ip: ip)
                    if let geo = geo {
                        await MainActor.run {
                            if let idx = self.hops.firstIndex(where: { $0.id == hop.id }) {
                                self.hops[idx].geoInfo = geo
                            }
                        }
                    }
                }
            }
            self.isRunning = false
            if !Task.isCancelled && self.hops.isEmpty {
                if let launchError = await runner.lastError {
                    self.errorMessage = String(format: String(localized: "Traceroute failed: %@", bundle: .module), launchError)
                } else {
                    self.errorMessage = String(localized: "No route could be traced. The target may be unreachable or blocking probes.", bundle: .module)
                }
            }
        }
    }

    func restartTraceroute() {
        guard let connection = selectedConnection else { return }
        startTraceroute(for: connection)
    }

    func cancel() {
        task?.cancel()
        task = nil
        Task {
            await runner.cancel()
        }
        isRunning = false
    }

    func clear() {
        cancel()
        hops = []
        selectedConnectionID = nil
        targetIP = ""
        errorMessage = nil
    }

    var totalHops: Int { hops.count }

    var totalRTT: Double? {
        let validRTTs = hops.compactMap { $0.rtt }
        guard !validRTTs.isEmpty else { return nil }
        return validRTTs.reduce(0, +)
    }

    var isComplete: Bool {
        !isRunning && !hops.isEmpty
    }
}
