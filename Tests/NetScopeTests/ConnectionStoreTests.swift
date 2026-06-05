import XCTest
@testable import NetScope

@MainActor
final class ConnectionStoreTests: XCTestCase {

    func testDeltaCalculation() {
        let store = ConnectionStore()

        // First update: connection appears with 1000 bytes in
        let conn1 = Connection(
            pid: 123, processName: "TestApp", localPort: 5000,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 1000, bytesOut: 500
        )
        store.update(with: [conn1])

        XCTAssertEqual(store.connections.count, 1)
        XCTAssertEqual(store.connections.first?.bytesIn, 1000)
        XCTAssertEqual(store.connections.first?.bytesOut, 500)
        XCTAssertEqual(store.connections.first?.rawBytesIn, 1000)
        XCTAssertEqual(store.connections.first?.rawBytesOut, 500)

        // Second update: raw cumulative increased to 3000 bytes in
        let conn2 = Connection(
            pid: 123, processName: "TestApp", localPort: 5000,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 3000, bytesOut: 1500
        )
        store.update(with: [conn2])

        XCTAssertEqual(store.connections.count, 1)
        // Delta should be 3000 - 1000 = 2000
        XCTAssertEqual(store.connections.first?.bytesIn, 2000)
        XCTAssertEqual(store.connections.first?.bytesOut, 1000)
        // Raw should reflect new cumulative
        XCTAssertEqual(store.connections.first?.rawBytesIn, 3000)
        XCTAssertEqual(store.connections.first?.rawBytesOut, 1500)
    }

    func testNegativeDeltaIsClampedToZero() {
        let store = ConnectionStore()

        let conn1 = Connection(
            pid: 123, processName: "TestApp", localPort: 5000,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 1000, bytesOut: 500
        )
        store.update(with: [conn1])

        // Data source reset (e.g., counter rolled over), raw decreased
        let conn2 = Connection(
            pid: 123, processName: "TestApp", localPort: 5000,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 500, bytesOut: 200
        )
        store.update(with: [conn2])

        XCTAssertEqual(store.connections.first?.bytesIn, 0)
        XCTAssertEqual(store.connections.first?.bytesOut, 0)
    }

    func testResetClearsConnections() {
        let store = ConnectionStore()

        let conn = Connection(
            pid: 123, processName: "TestApp", localPort: 5000,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 1000, bytesOut: 500
        )
        store.update(with: [conn])
        XCTAssertEqual(store.connections.count, 1)

        store.reset()
        XCTAssertEqual(store.connections.count, 0)
        XCTAssertNil(store.selectedProcess)
    }

    func testProcessColorConsistency() {
        let store = ConnectionStore()

        let conn1 = Connection(
            pid: 123, processName: "Chrome", localPort: 5000,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 1000, bytesOut: 500
        )
        let conn2 = Connection(
            pid: 456, processName: "Safari", localPort: 5001,
            remoteIP: "5.6.7.8", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 2000, bytesOut: 1000
        )
        store.update(with: [conn1, conn2])

        let color1 = store.colorForProcess("Chrome")
        let color2 = store.colorForProcess("Safari")
        let color1Again = store.colorForProcess("Chrome")

        XCTAssertEqual(color1, color1Again)
        XCTAssertNotEqual(color1, color2)
    }

    func testProcessesComputedCorrectly() {
        let store = ConnectionStore()

        let conn1 = Connection(
            pid: 123, processName: "Chrome", localPort: 5000,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 1000, bytesOut: 500
        )
        let conn2 = Connection(
            pid: 123, processName: "Chrome", localPort: 5001,
            remoteIP: "5.6.7.8", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 2000, bytesOut: 1000
        )
        let conn3 = Connection(
            pid: 456, processName: "Safari", localPort: 5002,
            remoteIP: "9.10.11.12", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 500, bytesOut: 250
        )
        store.update(with: [conn1, conn2, conn3])

        let processes = store.processes
        XCTAssertEqual(processes.count, 2)

        let chrome = processes.first { $0.name == "Chrome" }
        XCTAssertNotNil(chrome)
        XCTAssertEqual(chrome?.count, 2)

        let safari = processes.first { $0.name == "Safari" }
        XCTAssertNotNil(safari)
        XCTAssertEqual(safari?.count, 1)
    }

    func testSelectedProcessFiltering() {
        let store = ConnectionStore()

        let conn1 = Connection(
            pid: 123, processName: "Chrome", localPort: 5000,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 1000, bytesOut: 500
        )
        let conn2 = Connection(
            pid: 456, processName: "Safari", localPort: 5001,
            remoteIP: "5.6.7.8", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 2000, bytesOut: 1000
        )
        store.update(with: [conn1, conn2])

        store.selectProcess("Chrome")
        XCTAssertEqual(store.filteredConnections.count, 1)
        XCTAssertEqual(store.filteredConnections.first?.processName, "Chrome")

        store.selectProcess(nil)
        XCTAssertEqual(store.filteredConnections.count, 2)
    }
}
