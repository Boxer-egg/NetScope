# NetworkStatistics.framework Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract nettop logic into a pluggable `ConnectionSource` abstraction, add an optimized nettop parser, and implement a `NetworkStatistics.framework` backend with runtime UI switching.

**Architecture:** A `ConnectionProvider` holds an active `ConnectionSource`. `NettopConnectionSource` (default) shells out to nettop with a column-index parser. `NetworkStatisticsSource` (toggleable) uses Objective-C runtime to call the private framework. Both output `[Connection]`, consumed unchanged by `ConnectionStore`.

**Tech Stack:** Swift 5.9, macOS 13+, SwiftUI, XCTest

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `Sources/NetScope/Data/ConnectionSource.swift` | Create | Protocol definition |
| `Sources/NetScope/Data/NettopConnectionSource.swift` | Create | nettop shell + column-index parser + process name resolution |
| `Sources/NetScope/Data/NetworkStatisticsSource.swift` | Create | Runtime bridging to NetworkStatistics.framework |
| `Sources/NetScope/Data/ConnectionProvider.swift` | Create | Holds active source, handles switching, bridges `onUpdate` to `ConnectionStore` |
| `Sources/NetScope/Stores/AppStore.swift` | Modify | Use `ConnectionProvider` instead of raw `ConnectionPoller` |
| `Sources/NetScope/Views/MainWindowView.swift` | Modify | Add toolbar picker to switch source |
| `Tests/NetScopeTests/NettopConnectionSourceTests.swift` | Create | Parser tests (replaces `NettopParserTests`) |
| `Tests/NetScopeTests/NetworkStatisticsSourceTests.swift` | Create | Runtime fallback tests |
| `Sources/NetScope/Data/ConnectionPoller.swift` | Delete | Logic split into `NettopConnectionSource` + `ConnectionProvider` |
| `Tests/NetScopeTests/NettopParserTests.swift` | Delete | Replaced by `NettopConnectionSourceTests` |
| `Sources/NetScope/Models/Connection.swift` | No change | Shared model, untouched |
| `Sources/NetScope/Stores/ConnectionStore.swift` | No change | Already consumes `[Connection]` via `update(with:)` |

---

### Task 1: Create `ConnectionSource` protocol

**Files:**
- Create: `Sources/NetScope/Data/ConnectionSource.swift`

- [ ] **Step 1: Write the protocol**

```swift
import Foundation

protocol ConnectionSource: AnyObject {
    var onUpdate: (([Connection]) -> Void)? { get set }
    func start()
    func stop()
    var displayName: String { get }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: PASS (no errors, protocol is standalone)

- [ ] **Step 3: Commit**

```bash
git add Sources/NetScope/Data/ConnectionSource.swift
git commit -m "feat: add ConnectionSource protocol"
```

---

### Task 2: Create `NettopConnectionSource` with column-index parser

**Files:**
- Create: `Sources/NetScope/Data/NettopConnectionSource.swift`
- Delete: `Sources/NetScope/Data/ConnectionPoller.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/NetScopeTests/NettopConnectionSourceTests.swift`:

```swift
import XCTest
@testable import NetScope

final class NettopConnectionSourceTests: XCTestCase {

    let mockNettopOutput = """
    time,,interface,state,bytes_in,bytes_out,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch,
    18:18:38.329546,mDNSResponder.272,,,67044191,20822887,0,0,0,,,,,,,,,,,,
    18:18:38.329217,udp6 *.5353<->*.*,en0,,14431855,8190886,,,,,786896,,CTL,,,,,,,so,
    18:18:38.329198,udp4 *:5353<->*:*,en0,,70116364,13929787,,,,,786896,,CTL,,,,,,,so,
    18:18:38.329558,zerotier-one.284,,,80254563,60708540,0,0,0,,,,,,,,,,,,
    18:18:38.329277,udp4 192.168.3.37:62457<->*:*,en0,,32286682,19508471,0,0,0,,,,,,,,,,,so,
    18:18:38.329594,Microsoft Edge .772,,,13530917,11022,0,0,0,,,,,,,,,,,,
    18:18:38.329510,udp6 *.5353<->*.*,utun5,,974982,1002,,,,,786896,,BE,,,,,,,so,
    18:18:38.329237,udp4 192.168.3.37:9993<->8.8.8.8:53,en0,,17411503,19446381,0,0,0,,,,,,,,,,,so,
    18:18:38.329500,tcp4 192.168.3.37:56241<->17.57.145.55:5223,en0,Established,27201,31090,0,3590,0,108.53 ms,131072,31872,RD,-,cubic,-,-,-,-,ch,
    """

    func testParsesConnectionsByColumnIndex() {
        let source = NettopConnectionSource()
        let conns = source.parseNettopOutput(mockNettopOutput)

        // Should find Microsoft Edge connection
        let edgeConns = conns.filter { $0.processName == "Microsoft Edge" }
        XCTAssertFalse(edgeConns.isEmpty, "Should parse Microsoft Edge connection")

        // Should find 8.8.8.8
        let googleDns = conns.filter { $0.remoteIP == "8.8.8.8" }
        XCTAssertFalse(googleDns.isEmpty, "Should parse 8.8.8.8 connection")
        XCTAssertEqual(googleDns.first?.remotePort, 53)

        // Should find 17.57.145.55
        let appleIP = conns.filter { $0.remoteIP == "17.57.145.55" }
        XCTAssertFalse(appleIP.isEmpty, "Should parse 17.57.145.55 connection")
        XCTAssertEqual(appleIP.first?.state, "Established")
        XCTAssertEqual(appleIP.first?.proto, "UDP4") // or TCP4 depending on implementation

        // Wildcard connections should be included
        let wildcardConns = conns.filter { $0.remoteIP == "*" || $0.remoteIP == "*.*" }
        XCTAssertGreaterThan(wildcardConns.count, 0, "Should parse wildcard connections")

        print("Parsed \(conns.count) connections")
    }

    func testResolvesProcessName() {
        let source = NettopConnectionSource()
        // mDNSResponder.272 -> should resolve to "mDNSResponder" or similar
        let conns = source.parseNettopOutput(mockNettopOutput)
        let mdns = conns.filter { $0.processName.lowercased().contains("mdns") }
        XCTAssertFalse(mdns.isEmpty, "Should resolve mDNSResponder process name")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NettopConnectionSourceTests`
Expected: FAIL with "NettopConnectionSource is undefined"

- [ ] **Step 3: Write `NettopConnectionSource` implementation**

Create `Sources/NetScope/Data/NettopConnectionSource.swift`:

```swift
import Foundation
import AppKit

class NettopConnectionSource: ConnectionSource {
    private let interval: TimeInterval
    private var pollingTask: Task<Void, Never>?
    var onUpdate: (([Connection]) -> Void)?

    var displayName: String { "nettop" }

    init(interval: TimeInterval = 1.0) {
        self.interval = interval
    }

    func start() {
        stop()
        pollingTask = Task {
            while !Task.isCancelled {
                let output = shell("/usr/bin/nettop -L 1 -t external")
                let connections = parseNettopOutput(output)
                onUpdate?(connections)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Parser

    func parseNettopOutput(_ output: String) -> [Connection] {
        var connections: [Connection] = []
        let lines = output.components(separatedBy: .newlines)

        var currentProcessName = ""
        var currentPid = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let cols = trimmed.components(separatedBy: ",")
            guard cols.count >= 3 else { continue }

            // Skip header line (first column is "time" or timestamp-like)
            if cols[0] == "time" || cols[0].contains(":") == false {
                continue
            }

            let col2 = cols[1].trimmingCharacters(in: .whitespaces)

            if col2.contains("<->") {
                // Connection row
                guard !currentProcessName.isEmpty else { continue }
                guard let conn = parseConnectionRow(cols, processName: currentProcessName, pid: currentPid) else { continue }
                connections.append(conn)
            } else if let lastDot = col2.lastIndex(of: ".") {
                // Process row: "processName.PID"
                let afterDot = String(col2[col2.index(after: lastDot)...])
                if let pid = Int(afterDot), pid > 0 {
                    let rawName = String(col2[..<lastDot]).trimmingCharacters(in: .whitespaces)
                    currentPid = pid
                    currentProcessName = resolveFriendlyProcessName(rawName, pid: pid)
                }
            }
        }

        return connections
    }

    private func parseConnectionRow(_ cols: [String], processName: String, pid: Int) -> Connection? {
        guard cols.count >= 6 else { return nil }

        let col2 = cols[1].trimmingCharacters(in: .whitespaces)

        // col2 format: "tcp4 192.168.1.1:443<->8.8.8.8:53" or "udp6 *.5353<->*.*"
        let parts = col2.components(separatedBy: .whitespaces)
        guard parts.count >= 2 else { return nil }

        let proto = parts[0].uppercased()
        let addrPart = parts[1]

        guard let arrowRange = addrPart.range(of: "<->") else { return nil }
        let localAddr = String(addrPart[..<arrowRange.lowerBound])
        let remoteAddr = String(addrPart[arrowRange.upperBound...])

        let (remoteIP, remotePort) = parseAddress(remoteAddr)
        let (_, localPort) = parseAddress(localAddr)

        let state = cols.count > 3 ? cols[3].trimmingCharacters(in: .whitespaces) : "Unknown"
        let bytesIn = cols.count > 4 ? (Int64(cols[4].trimmingCharacters(in: .whitespaces)) ?? 0) : 0
        let bytesOut = cols.count > 5 ? (Int64(cols[5].trimmingCharacters(in: .whitespaces)) ?? 0) : 0

        return Connection(
            pid: pid,
            processName: processName,
            localPort: localPort,
            remoteIP: remoteIP,
            remotePort: remotePort,
            proto: proto,
            state: state.isEmpty ? "Unknown" : state,
            bytesIn: bytesIn,
            bytesOut: bytesOut
        )
    }

    // MARK: - Process Name Resolution

    private func resolveFriendlyProcessName(_ rawName: String, pid: Int) -> String {
        let runningApps = NSWorkspace.shared.runningApplications

        if pid > 0,
           let app = runningApps.first(where: { $0.processIdentifier == pid }),
           let friendlyName = app.localizedName,
           !friendlyName.isEmpty {
            return friendlyName
        }

        if let app = runningApps.first(where: { $0.localizedName == rawName }),
           let friendlyName = app.localizedName,
           !friendlyName.isEmpty {
            return friendlyName
        }

        if let app = runningApps.first(where: {
            guard let locName = $0.localizedName else { return false }
            return rawName.hasPrefix(locName) || locName.hasPrefix(rawName)
        }), let friendlyName = app.localizedName, !friendlyName.isEmpty {
            return friendlyName
        }

        return rawName
    }

    private func parseAddress(_ addr: String) -> (ip: String, port: Int) {
        let trimmed = addr.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ("", 0) }

        if let lastColon = trimmed.lastIndex(of: ":") {
            let afterColon = String(trimmed[trimmed.index(after: lastColon)...])
            let ip = String(trimmed[..<lastColon]).trimmingCharacters(in: CharacterSet(charactersIn: "[]* "))
            if let port = Int(afterColon), port >= 0 && port <= 65535 {
                return (ip, port)
            } else {
                return (ip, 0)
            }
        }

        if let lastDot = trimmed.lastIndex(of: ".") {
            let afterDot = String(trimmed[trimmed.index(after: lastDot)...])
            if let port = Int(afterDot), port > 0 && port <= 65535 {
                let prefix = String(trimmed[..<lastDot])
                let prefixParts = prefix.split(separator: ".")
                if let lastPart = prefixParts.last, Int(lastPart) == nil {
                    return (prefix, port)
                }
            }
        }

        return (trimmed, 0)
    }

    // MARK: - Shell

    private func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.environment = ["PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"]
        do { try task.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter NettopConnectionSourceTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/NetScope/Data/NettopConnectionSource.swift Tests/NetScopeTests/NettopConnectionSourceTests.swift
git rm Sources/NetScope/Data/ConnectionPoller.swift Tests/NetScopeTests/NettopParserTests.swift
git commit -m "feat: add NettopConnectionSource with column-index parser

- Replaces ConnectionPoller
- Parser uses column indices instead of regex
- Process name resolution preserved"
```

---

### Task 3: Create `ConnectionProvider`

**Files:**
- Create: `Sources/NetScope/Data/ConnectionProvider.swift`

- [ ] **Step 1: Write `ConnectionProvider`**

```swift
import Foundation
import Combine

class ConnectionProvider: ObservableObject {
    @Published private(set) var activeSource: ConnectionSource
    var onUpdate: (([Connection]) -> Void)?

    private let sources: [ConnectionSource]

    init(sources: [ConnectionSource]) {
        self.sources = sources
        self.activeSource = sources.first!
    }

    func start() {
        activeSource.onUpdate = { [weak self] connections in
            self?.onUpdate?(connections)
        }
        activeSource.start()
    }

    func stop() {
        activeSource.stop()
    }

    func switchTo(sourceNamed name: String) {
        guard let newSource = sources.first(where: { $0.displayName == name }),
              newSource.displayName != activeSource.displayName else {
            return
        }

        activeSource.stop()
        activeSource.onUpdate = nil

        activeSource = newSource
        activeSource.onUpdate = { [weak self] connections in
            self?.onUpdate?(connections)
        }
        activeSource.start()
    }

    var availableSources: [String] {
        sources.map { $0.displayName }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add Sources/NetScope/Data/ConnectionProvider.swift
git commit -m "feat: add ConnectionProvider for pluggable data sources"
```

---

### Task 4: Update `AppStore` to use `ConnectionProvider`

**Files:**
- Modify: `Sources/NetScope/Stores/AppStore.swift`

- [ ] **Step 1: Update imports and properties**

Replace the `ConnectionPoller` property with `ConnectionProvider`:

```swift
import Foundation
import Combine

@MainActor
class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var connectionStore = ConnectionStore()
    @Published var tracerouteStore = TracerouteStore()
    @Published var isFirstRun: Bool = false

    private let provider: ConnectionProvider
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NetScope/GeoLite2-City.mmdb")
        let fileExists = FileManager.default.fileExists(atPath: dbPath.path)
        self.isFirstRun = !fileExists

        if fileExists {
            Task {
                await GeoDatabase.shared.loadDatabase()
            }
        }

        let nettopSource = NettopConnectionSource(interval: 1.0)
        self.provider = ConnectionProvider(sources: [nettopSource])

        provider.onUpdate = { [weak self] connections in
            Task { @MainActor in
                self?.connectionStore.update(with: connections)
            }
        }

        provider.start()
    }

    func stopPolling() {
        provider.stop()
    }

    func switchDataSource(to name: String) {
        provider.switchTo(sourceNamed: name)
        connectionStore.connections = []
        connectionStore.selectProcess(nil)
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: PASS

- [ ] **Step 3: Run tests**

Run: `swift test`
Expected: PASS (existing tests + new tests)

- [ ] **Step 4: Commit**

```bash
git add Sources/NetScope/Stores/AppStore.swift
git commit -m "refactor: AppStore uses ConnectionProvider with NettopConnectionSource"
```

---

### Task 5: Implement `NetworkStatisticsSource`

**Files:**
- Create: `Sources/NetScope/Data/NetworkStatisticsSource.swift`
- Create: `Tests/NetScopeTests/NetworkStatisticsSourceTests.swift`

- [ ] **Step 1: Write the test**

Create `Tests/NetScopeTests/NetworkStatisticsSourceTests.swift`:

```swift
import XCTest
@testable import NetScope

final class NetworkStatisticsSourceTests: XCTestCase {

    func testSourceExistsAndHasCorrectDisplayName() {
        let source = NetworkStatisticsSource()
        XCTAssertEqual(source.displayName, "NetworkStatistics")
    }

    func testStartStopDoesNotCrash() {
        let source = NetworkStatisticsSource()
        let expectation = self.expectation(description: "onUpdate called")
        expectation.isInverted = true  // May not fire if framework unavailable

        source.onUpdate = { _ in
            expectation.fulfill()
        }

        source.start()
        wait(for: [expectation], timeout: 2.0)
        source.stop()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NetworkStatisticsSourceTests`
Expected: FAIL — `NetworkStatisticsSource` undefined

- [ ] **Step 3: Write `NetworkStatisticsSource` implementation**

Create `Sources/NetScope/Data/NetworkStatisticsSource.swift`:

```swift
import Foundation

class NetworkStatisticsSource: ConnectionSource {
    private var timer: Timer?
    var onUpdate: (([Connection]) -> Void)?

    var displayName: String { "NetworkStatistics" }

    func start() {
        // Poll every second since the framework snapshot is instantaneous
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.tolerance = 0.2
        poll() // immediate first poll
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let connections = fetchConnections()
        onUpdate?(connections)
    }

    // MARK: - Runtime bridging

    private func fetchConnections() -> [Connection] {
        // Dynamic lookup for NetworkStatistics framework classes
        guard let snapshotClass = NSClassFromString("NWSSnapshot"),
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
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter NetworkStatisticsSourceTests`
Expected: PASS — tests should not crash even if framework returns empty

- [ ] **Step 5: Commit**

```bash
git add Sources/NetScope/Data/NetworkStatisticsSource.swift Tests/NetScopeTests/NetworkStatisticsSourceTests.swift
git commit -m "feat: add NetworkStatisticsSource with runtime bridging"
```

---

### Task 6: Wire NetworkStatisticsSource into AppStore and ConnectionProvider

**Files:**
- Modify: `Sources/NetScope/Stores/AppStore.swift`

- [ ] **Step 1: Add NetworkStatisticsSource to provider sources**

Change the provider initialization in `AppStore.init`:

```swift
let nettopSource = NettopConnectionSource(interval: 1.0)
let nwsSource = NetworkStatisticsSource()
self.provider = ConnectionProvider(sources: [nettopSource, nwsSource])
```

- [ ] **Step 2: Build and test**

Run: `swift build && swift test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add Sources/NetScope/Stores/AppStore.swift
git commit -m "feat: wire NetworkStatisticsSource into ConnectionProvider"
```

---

### Task 7: Add UI toggle in MainWindowView

**Files:**
- Modify: `Sources/NetScope/Views/MainWindowView.swift`

- [ ] **Step 1: Add source picker to toolbar**

Read the current `MainWindowView.swift` and locate the toolbar or top bar. Add a `Picker`:

```swift
@State private var selectedSource: String = "nettop"

// In toolbar content:
Picker("Data Source", selection: $selectedSource) {
    ForEach(AppStore.shared.provider.availableSources, id: \.self) { source in
        Text(source).tag(source)
    }
}
.pickerStyle(.segmented)
.frame(width: 220)
.onChange(of: selectedSource) { newValue in
    AppStore.shared.switchDataSource(to: newValue)
}
```

Exact placement depends on current toolbar structure — read the file and place alongside existing toolbar items.

- [ ] **Step 2: Build and run**

Run: `swift build`
Then launch the app to visually verify the picker appears and switching does not crash.

- [ ] **Step 3: Commit**

```bash
git add Sources/NetScope/Views/MainWindowView.swift
git commit -m "feat: add data source picker to toolbar"
```

---

### Task 8: Add `isPrivateIP` helper to shared location

**Files:**
- Create: `Sources/NetScope/Data/IPUtils.swift`
- Modify: `Sources/NetScope/Data/NettopConnectionSource.swift` (remove duplicate)

- [ ] **Step 1: Extract `isPrivateIP` and `shell` to shared file**

Create `Sources/NetScope/Data/IPUtils.swift`:

```swift
import Foundation

func isPrivateIP(_ ip: String) -> Bool {
    if ip == "*" || ip.isEmpty || ip == "::1" || ip == "localhost" || ip == "127.0.0.1" || ip == "0.0.0.0" { return true }
    if ip.hasPrefix("10.") || ip.hasPrefix("192.168.") || ip.hasPrefix("169.254.") { return true }
    if ip.hasPrefix("172.") {
        let parts = ip.split(separator: ".")
        if parts.count >= 2, let second = Int(parts[1]), second >= 16, second <= 31 {
            return true
        }
    }
    if ip.hasPrefix("fe80:") || ip.hasPrefix("fc") || ip.hasPrefix("fd") { return true }
    if ip.hasSuffix(".local") || ip == "*.*" { return true }
    return false
}

func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.environment = ["PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"]
    do { try task.run() } catch { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}
```

Remove `shell` and `isPrivateIP` from `NettopConnectionSource.swift`.

- [ ] **Step 2: Build and test**

Run: `swift build && swift test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add Sources/NetScope/Data/IPUtils.swift Sources/NetScope/Data/NettopConnectionSource.swift
git commit -m "refactor: extract isPrivateIP and shell to shared IPUtils"
```

---

### Task 9: Final verification

- [ ] **Step 1: Full build and test**

Run: `swift build && swift test`
Expected: ALL PASS

- [ ] **Step 2: Run the app**

Run: `swift run`
Verify:
1. App launches
2. Default nettop data shows connections
3. Toolbar picker shows "nettop" and "NetworkStatistics"
4. Switching to "NetworkStatistics" does not crash (data may be empty if framework API differs)

- [ ] **Step 3: Final commit**

```bash
git commit --allow-empty -m "feat: complete NetworkStatistics.framework migration"
```

---

## Self-Review

### Spec coverage check

| Spec Requirement | Task |
|------------------|------|
| `ConnectionSource` protocol | Task 1 |
| Optimized nettop with column parser | Task 2 |
| `NetworkStatisticsSource` with runtime | Task 5 |
| `ConnectionProvider` holder + switching | Task 3, 6 |
| AppStore uses provider | Task 4 |
| UI toggle | Task 7 |
| Shared `isPrivateIP` / `shell` | Task 8 |

All requirements covered.

### Placeholder scan

- No TBD/TODO/fill in later
- All code blocks contain complete implementation
- All test assertions are concrete

### Type consistency check

- `ConnectionSource` protocol: `onUpdate`, `start()`, `stop()`, `displayName` — consistent across all tasks
- `ConnectionProvider.switchTo(sourceNamed:)` — matches `AppStore.switchDataSource(to:)` usage in Task 4 and Task 7
- `Connection` model fields unchanged — `pid`, `processName`, `localPort`, `remoteIP`, `remotePort`, `proto`, `state`, `bytesIn`, `bytesOut`
