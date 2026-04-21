import Testing
@testable import NetScope

@MainActor
struct ConnectionStoreTests {

    @Test func testConnectionIDUniqueness() async throws {
        let c1 = Connection(pid: 123, processName: "Safari", localPort: 5000, remoteIP: "8.8.8.8", remotePort: 443, proto: "TCP", state: "ESTABLISHED")
        let c2 = Connection(pid: 123, processName: "Safari", localPort: 5000, remoteIP: "8.8.8.8", remotePort: 443, proto: "TCP", state: "ESTABLISHED")
        let c3 = Connection(pid: 123, processName: "Safari", localPort: 5001, remoteIP: "8.8.8.8", remotePort: 443, proto: "TCP", state: "ESTABLISHED")

        #expect(c1.id == c2.id, "Same connection should have same ID")
        #expect(c1.id != c3.id, "Different local port should have different ID")
    }

    @Test func testIncrementalUpdate() async throws {
        let store = ConnectionStore()

        let conn1 = Connection(pid: 100, processName: "Safari", localPort: 5000, remoteIP: "8.8.8.8", remotePort: 443, proto: "TCP", state: "ESTABLISHED")
        let conn2 = Connection(pid: 200, processName: "Chrome", localPort: 6000, remoteIP: "1.1.1.1", remotePort: 443, proto: "TCP", state: "ESTABLISHED")

        store.update(with: [conn1, conn2])
        #expect(store.connections.count == 2)

        // Remove conn2, add conn3
        let conn3 = Connection(pid: 300, processName: "Firefox", localPort: 7000, remoteIP: "9.9.9.9", remotePort: 443, proto: "TCP", state: "ESTABLISHED")
        store.update(with: [conn1, conn3])
        #expect(store.connections.count == 2)
        #expect(store.connections.contains(where: { $0.processName == "Safari" }))
        #expect(store.connections.contains(where: { $0.processName == "Firefox" }))
        #expect(!store.connections.contains(where: { $0.processName == "Chrome" }))
    }
}
