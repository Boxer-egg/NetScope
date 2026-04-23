import Foundation
import Darwin

class NetworkStatisticsSource: ConnectionSource {
    var onUpdate: (([Connection]) -> Void)?

    var displayName: String { "NetworkStatistics" }

    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.netscope.nstat")

    // C API handles
    private var handle: UnsafeMutableRawPointer?
    private var manager: NStatManagerRef?
    private var sources: [NStatSourceRef] = []
    private var sourceData: [NStatSourceRef: [String: Any]] = [:]
    private var isPolling = false

    func start() {
        guard loadAPI() else {
            onUpdate?([])
            return
        }

        createManager()
        addAllSources()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.tolerance = 0.2
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let handle = handle, let manager = manager {
            let destroy = unsafeBitCast(dlsym(handle, "NStatManagerDestroy")!,
                to: NStatManagerDestroyFunc.self)
            destroy(manager)
        }
        queue.sync {
            sources.removeAll()
            sourceData.removeAll()
            self.manager = nil
        }
        if let handle = handle {
            dlclose(handle)
            self.handle = nil
        }
    }

    // MARK: - C API Loading

    private func loadAPI() -> Bool {
        handle = dlopen("/System/Library/PrivateFrameworks/NetworkStatistics.framework/Versions/A/NetworkStatistics", RTLD_NOW)
        guard handle != nil else { return false }

        let required = [
            "NStatManagerCreate",
            "NStatManagerDestroy",
            "NStatManagerAddAllTCP",
            "NStatManagerAddAllUDP",
            "NStatManagerQueryAllSources",
            "NStatManagerQueryAllSourcesDescriptions",
            "NStatSourceSetCountsBlock",
            "NStatSourceSetDescriptionBlock",
            "NStatSourceSetRemovedBlock",
        ]
        for sym in required {
            if dlsym(handle, sym) == nil {
                return false
            }
        }
        return true
    }

    private func createManager() {
        guard let handle = handle else { return }

        let create = unsafeBitCast(dlsym(handle, "NStatManagerCreate")!,
            to: NStatManagerCreateFunc.self)

        let block: @convention(block) (NStatSourceRef) -> Void = { [weak self] src in
            self?.addSource(src)
        }

        manager = create(nil, queue, block)
    }

    private func addAllSources() {
        guard let handle = handle, let manager = manager else { return }

        let addTCP = unsafeBitCast(dlsym(handle, "NStatManagerAddAllTCP")!,
            to: NStatManagerAddAllFunc.self)
        let addUDP = unsafeBitCast(dlsym(handle, "NStatManagerAddAllUDP")!,
            to: NStatManagerAddAllFunc.self)

        addTCP(manager)
        addUDP(manager)
    }

    private func addSource(_ src: NStatSourceRef) {
        guard !sources.contains(where: { $0 == src }) else { return }
        sources.append(src)

        guard let handle = handle else { return }

        let setCounts = unsafeBitCast(dlsym(handle, "NStatSourceSetCountsBlock")!,
            to: NStatSourceSetBlockFunc.self)
        let setDescription = unsafeBitCast(dlsym(handle, "NStatSourceSetDescriptionBlock")!,
            to: NStatSourceSetBlockFunc.self)
        let setRemoved = unsafeBitCast(dlsym(handle, "NStatSourceSetRemovedBlock")!,
            to: NStatSourceSetRemovedBlockFunc.self)

        let countsBlock: @convention(block) (NSDictionary) -> Void = { [weak self] dict in
            guard let props = dict as? [String: Any] else { return }
            self?.queue.async { [weak self] in
                guard let self = self else { return }
                var merged = self.sourceData[src] ?? [:]
                for (key, value) in props {
                    merged[key] = value
                }
                self.sourceData[src] = merged
            }
        }
        let descriptionBlock: @convention(block) (NSDictionary) -> Void = { [weak self] dict in
            guard let props = dict as? [String: Any] else { return }
            self?.queue.async { [weak self] in
                guard let self = self else { return }
                var merged = self.sourceData[src] ?? [:]
                for (key, value) in props {
                    merged[key] = value
                }
                self.sourceData[src] = merged
            }
        }
        let removedBlock: @convention(block) () -> Void = { [weak self] in
            self?.removeSource(src)
        }

        setCounts(src, countsBlock)
        setDescription(src, descriptionBlock)
        setRemoved(src, removedBlock)
    }

    private func removeSource(_ src: NStatSourceRef) {
        sources.removeAll { $0 == src }
        sourceData.removeValue(forKey: src)
    }

    // MARK: - Polling

    private func poll() {
        guard let handle = handle, let manager = manager else {
            onUpdate?([])
            return
        }
        guard !isPolling else { return }
        isPolling = true

        let queryDescriptions = unsafeBitCast(
            dlsym(handle, "NStatManagerQueryAllSourcesDescriptions")!,
            to: NStatManagerQueryFunc.self)
        let queryCounts = unsafeBitCast(
            dlsym(handle, "NStatManagerQueryAllSources")!,
            to: NStatManagerQueryFunc.self)

        queue.async { [weak self] in
            queryDescriptions(manager) {
                queryCounts(manager) {
                    self?.buildConnections()
                }
            }
        }
    }

    private func buildConnections() {
        var connections: [Connection] = []
        for props in sourceData.values {
            if let conn = parseProperties(props) {
                connections.append(conn)
            }
        }

        isPolling = false
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(connections)
        }
    }

    // MARK: - Property Parsing

    private func parseProperties(_ props: [String: Any]) -> Connection? {
        let pid = props["processID"] as? Int ?? 0
        let processName = props["processName"] as? String ?? "Unknown"
        let provider = props["provider"] as? String ?? "TCP"

        let localAddrData = props["localAddress"] as? Data
        let remoteAddrData = props["remoteAddress"] as? Data

        let (_, localPort) = parseSockaddr(localAddrData)
        let (remoteIP, remotePort) = parseSockaddr(remoteAddrData)

        guard !remoteIP.isEmpty, remotePort > 0 else { return nil }

        if remoteIP.hasPrefix("127.") || remoteIP == "::1" {
            return nil
        }

        let state = props["TCPState"] as? String
            ?? props["state"] as? String
            ?? "Unknown"

        let rxBytes = props["rxBytes"] as? Int64 ?? 0
        let txBytes = props["txBytes"] as? Int64 ?? 0

        return Connection(
            pid: pid,
            processName: processName,
            localPort: localPort,
            remoteIP: remoteIP,
            remotePort: remotePort,
            proto: provider.uppercased(),
            state: state,
            bytesIn: rxBytes,
            bytesOut: txBytes
        )
    }

    private func parseSockaddr(_ data: Data?) -> (ip: String, port: Int) {
        guard let data = data, data.count >= MemoryLayout<sockaddr>.size else {
            return ("", 0)
        }

        return data.withUnsafeBytes { ptr -> (String, Int) in
            let sa = ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self).pointee
            switch Int32(sa.sa_family) {
            case AF_INET:
                guard data.count >= MemoryLayout<sockaddr_in>.size else { return ("", 0) }
                let sin = ptr.baseAddress!.assumingMemoryBound(to: sockaddr_in.self).pointee
                var addr = sin.sin_addr
                var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &addr, &ipBuf, socklen_t(INET_ADDRSTRLEN))
                let port = Int(UInt16(sin.sin_port).byteSwapped)
                return (String(cString: ipBuf), port)

            case AF_INET6:
                guard data.count >= MemoryLayout<sockaddr_in6>.size else { return ("", 0) }
                let sin6 = ptr.baseAddress!.assumingMemoryBound(to: sockaddr_in6.self).pointee
                var addr = sin6.sin6_addr
                var ipBuf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                inet_ntop(AF_INET6, &addr, &ipBuf, socklen_t(INET6_ADDRSTRLEN))
                let port = Int(UInt16(sin6.sin6_port).byteSwapped)
                return (String(cString: ipBuf), port)

            default:
                return ("", 0)
            }
        }
    }
}

// MARK: - C API Types

private typealias NStatManagerRef = UnsafeMutableRawPointer
private typealias NStatSourceRef = UnsafeMutableRawPointer

private typealias NStatManagerCreateFunc = @convention(c) (
    CFAllocator?, dispatch_queue_t, (@convention(block) (NStatSourceRef) -> Void)?
) -> NStatManagerRef

private typealias NStatManagerAddAllFunc = @convention(c) (NStatManagerRef) -> Void

private typealias NStatManagerDestroyFunc = @convention(c) (NStatManagerRef) -> Void

private typealias NStatManagerQueryFunc = @convention(c) (
    NStatManagerRef, (@convention(block) () -> Void)?
) -> Void

private typealias NStatSourceSetBlockFunc = @convention(c) (
    NStatSourceRef, @convention(block) (NSDictionary) -> Void
) -> Void

private typealias NStatSourceSetRemovedBlockFunc = @convention(c) (
    NStatSourceRef, @convention(block) () -> Void
) -> Void
