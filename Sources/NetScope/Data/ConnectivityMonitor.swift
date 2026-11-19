import Foundation

@MainActor
final class ConnectivityMonitor: ObservableObject {
    @Published private(set) var latency: Double?

    private var timer: Timer?
    private let host: String
    private let interval: TimeInterval

    init(host: String = "1.1.1.1", interval: TimeInterval = 15) {
        self.host = host
        self.interval = interval
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { await self.pingOnce() }
        }
        Task { await pingOnce() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func pingOnce() async {
        let host = self.host
        let result = await Task.detached {
            Self.ping(host: host)
        }.value
        latency = result
    }

    /// Runs one ICMP ping and parses the round-trip time, nil when unreachable.
    nonisolated static func ping(host: String) -> Double? {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/sbin/ping")
        p.arguments = ["-c", "1", "-t", "3", host]
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice

        do {
            try p.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        guard let range = output.range(of: "time=") else { return nil }
        let tail = output[range.upperBound...]
        let number = tail.prefix(while: { $0.isNumber || $0 == "." })
        return Double(number)
    }
}
