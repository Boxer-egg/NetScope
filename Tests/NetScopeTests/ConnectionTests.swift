import XCTest
@testable import NetScope

final class ConnectionTests: XCTestCase {

    func testIDIncludesProtocol() {
        let tcpConn = Connection(
            pid: 123, processName: "Chrome", localPort: 5000,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 1000, bytesOut: 500
        )
        let udpConn = Connection(
            pid: 123, processName: "Chrome", localPort: 5000,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "UDP",
            state: "Established", bytesIn: 1000, bytesOut: 500
        )

        XCTAssertNotEqual(tcpConn.id, udpConn.id)
        XCTAssertTrue(tcpConn.id.contains("TCP"))
        XCTAssertTrue(udpConn.id.contains("UDP"))
    }

    func testIDDifferentiatesSameEndpoint() {
        let conn1 = Connection(
            pid: 123, processName: "Chrome", localPort: 5000,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 1000, bytesOut: 500
        )
        let conn2 = Connection(
            pid: 123, processName: "Chrome", localPort: 5001,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 2000, bytesOut: 1000
        )

        XCTAssertNotEqual(conn1.id, conn2.id)
    }

    func testFormatRate() {
        XCTAssertEqual(Connection.formatRate(0), "0 B/s")
        XCTAssertEqual(Connection.formatRate(50), "0 B/s")
        XCTAssertEqual(Connection.formatRate(103), "0.1 KB/s")
        XCTAssertEqual(Connection.formatRate(1024), "1.0 KB/s")
        XCTAssertEqual(Connection.formatRate(1048576), "1.0 MB/s")
        XCTAssertEqual(Connection.formatRate(1572864), "1.5 MB/s")
    }
}
