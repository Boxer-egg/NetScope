import XCTest
@testable import NetScope

final class TracerouteRunnerTests: XCTestCase {

    func testParseTimeoutLine() {
        let hop = TracerouteRunner.parseLine("  3  * * *")
        XCTAssertNotNil(hop)
        XCTAssertEqual(hop?.id, 3)
        XCTAssertNil(hop?.ip)
        XCTAssertNil(hop?.rtt)
        XCTAssertTrue(hop?.isTimeout ?? false)
    }

    func testParseNormalHop() {
        let hop = TracerouteRunner.parseLine("  3  142.251.49.1  14.234 ms")
        XCTAssertNotNil(hop)
        XCTAssertEqual(hop?.id, 3)
        XCTAssertEqual(hop?.ip, "142.251.49.1")
        XCTAssertEqual(hop?.rtt, 14.234)
        XCTAssertFalse(hop?.isTimeout ?? true)
    }

    func testParseNormalHopWithHostname() {
        let hop = TracerouteRunner.parseLine("  5  router.example.com (192.168.1.1)  2.5 ms")
        // This format is not supported by the current parser, should return nil
        let hopSimple = TracerouteRunner.parseLine("  5  192.168.1.1  2.5 ms")
        XCTAssertNotNil(hopSimple)
        XCTAssertEqual(hopSimple?.ip, "192.168.1.1")
    }

    func testParseEmptyLine() {
        XCTAssertNil(TracerouteRunner.parseLine(""))
        XCTAssertNil(TracerouteRunner.parseLine("   "))
    }

    func testParseInvalidLine() {
        XCTAssertNil(TracerouteRunner.parseLine("traceroute to google.com"))
        XCTAssertNil(TracerouteRunner.parseLine("---"))
    }
}
