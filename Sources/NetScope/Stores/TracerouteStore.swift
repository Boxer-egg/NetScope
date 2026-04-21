import Foundation
import Combine

@MainActor
class TracerouteStore: ObservableObject {
    @Published var hops: [TracerouteHop] = []
    @Published var isRunning = false
    @Published var selectedConnectionID: String? = nil
    @Published var targetIP: String = ""
    @Published var errorMessage: String? = nil

    private var runner = TracerouteRunner()
    private var task: Task<Void, Never>?

    func startTraceroute(for connection: Connection) {
        // Cancel existing
        cancel()

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
        }
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
