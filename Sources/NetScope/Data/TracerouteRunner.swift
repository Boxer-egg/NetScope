import Foundation

actor TracerouteRunner {
    private var process: Process?
    private var isRunning = false

    func run(target: String) -> AsyncStream<TracerouteHop> {
        AsyncStream { continuation in
            Task {
                await cancel()
                isRunning = true

                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/sbin/traceroute")
                p.arguments = ["-n", "-m", "20", "-q", "1", target]
                let pipe = Pipe()
                p.standardOutput = pipe

                p.terminationHandler = { _ in
                    continuation.finish()
                }

                do {
                    try p.run()
                    self.process = p
                } catch {
                    continuation.finish()
                    return
                }

                // Synchronously read output line by line
                let handle = pipe.fileHandleForReading
                var buffer = Data()

                while self.isRunning {
                    let data = handle.availableData
                    if data.isEmpty {
                        // Check if process has terminated
                        if !p.isRunning {
                            break
                        }
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                        continue
                    }

                    buffer.append(data)

                    // Process complete lines
                    while let newlineRange = buffer.range(of: Data([0x0A])) {
                        let lineData = buffer.subdata(in: 0..<newlineRange.upperBound)
                        buffer.removeSubrange(0..<newlineRange.upperBound)

                        if let line = String(data: lineData, encoding: .utf8) {
                            if let hop = Self.parseLine(line) {
                                continuation.yield(hop)
                            }
                        }
                    }
                }

                // Process remaining buffer
                if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8) {
                    if let hop = Self.parseLine(line) {
                        continuation.yield(hop)
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.cancel()
                }
            }
        }
    }

    func cancel() {
        process?.terminate()
        process = nil
        isRunning = false
    }

    static func parseLine(_ line: String) -> TracerouteHop? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Timeout line: " 3  * * *"
        if let timeoutMatch = trimmed.range(of: #"^\s*(\d+)\s+\*"#, options: .regularExpression) {
            let numStr = trimmed[timeoutMatch].replacingOccurrences(of: #"^\s*(\d+)\s+\*"#,
                with: "$1", options: .regularExpression)
            if let num = Int(numStr) {
                return TracerouteHop(id: num, ip: nil, rtt: nil, geoInfo: nil)
            }
        }

        // Normal hop: " 3  142.251.49.1  14.234 ms"
        let pattern = #"^\s*(\d+)\s+(\S+)\s+([\d.]+)\s*ms"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) {
            let numRange = Range(match.range(at: 1), in: trimmed)!
            let ipRange = Range(match.range(at: 2), in: trimmed)!
            let rttRange = Range(match.range(at: 3), in: trimmed)!

            guard let num = Int(trimmed[numRange]),
                  let rtt = Double(trimmed[rttRange]) else { return nil }

            let ip = String(trimmed[ipRange])
            return TracerouteHop(id: num, ip: ip, rtt: rtt, geoInfo: nil)
        }

        return nil
    }
}
