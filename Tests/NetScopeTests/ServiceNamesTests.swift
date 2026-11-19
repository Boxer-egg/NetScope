import XCTest
@testable import NetScope

final class ServiceNamesTests: XCTestCase {

    func testWellKnownTCPPorts() {
        XCTAssertEqual(ServiceNames.serviceName(port: 443, proto: "TCP"), "HTTPS")
        XCTAssertEqual(ServiceNames.serviceName(port: 80, proto: "TCP"), "HTTP")
        XCTAssertEqual(ServiceNames.serviceName(port: 22, proto: "TCP"), "SSH")
        XCTAssertEqual(ServiceNames.serviceName(port: 5223, proto: "TCP"), "APN")
        XCTAssertEqual(ServiceNames.serviceName(port: 53, proto: "TCP"), "DNS")
    }

    func testUDP443IsQUIC() {
        XCTAssertEqual(ServiceNames.serviceName(port: 443, proto: "UDP"), "QUIC")
        XCTAssertEqual(ServiceNames.serviceName(port: 443, proto: "udp"), "QUIC")
    }

    func testUDPDNS() {
        XCTAssertEqual(ServiceNames.serviceName(port: 53, proto: "UDP"), "DNS")
    }

    func testUnknownPortReturnsNil() {
        XCTAssertNil(ServiceNames.serviceName(port: 49999, proto: "TCP"))
        XCTAssertNil(ServiceNames.serviceName(port: 0, proto: "TCP"))
    }
}
