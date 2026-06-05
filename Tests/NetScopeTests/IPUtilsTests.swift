import XCTest
@testable import NetScope

final class IPUtilsTests: XCTestCase {

    func testPrivateIPs() {
        XCTAssertTrue(isPrivateIP("127.0.0.1"))
        XCTAssertTrue(isPrivateIP("::1"))
        XCTAssertTrue(isPrivateIP("localhost"))
        XCTAssertTrue(isPrivateIP("0.0.0.0"))
        XCTAssertTrue(isPrivateIP("10.0.0.1"))
        XCTAssertTrue(isPrivateIP("10.255.255.255"))
        XCTAssertTrue(isPrivateIP("192.168.1.1"))
        XCTAssertTrue(isPrivateIP("192.168.0.0"))
        XCTAssertTrue(isPrivateIP("169.254.1.1"))
        XCTAssertTrue(isPrivateIP("172.16.0.1"))
        XCTAssertTrue(isPrivateIP("172.31.255.255"))
        XCTAssertTrue(isPrivateIP("fe80::1"))
        XCTAssertTrue(isPrivateIP("fc00::1"))
        XCTAssertTrue(isPrivateIP("fd00::1"))
        XCTAssertTrue(isPrivateIP("*.local"))
        XCTAssertTrue(isPrivateIP("*"))
        XCTAssertTrue(isPrivateIP("*.*"))
        XCTAssertTrue(isPrivateIP(""))
    }

    func testPublicIPs() {
        XCTAssertFalse(isPrivateIP("8.8.8.8"))
        XCTAssertFalse(isPrivateIP("1.1.1.1"))
        XCTAssertFalse(isPrivateIP("142.251.49.1"))
        XCTAssertFalse(isPrivateIP("172.32.0.1"))
        XCTAssertFalse(isPrivateIP("11.0.0.1"))
        XCTAssertFalse(isPrivateIP("9.0.0.1"))
    }
}
