import XCTest
@testable import NetScope

final class SystemProcessCheckerTests: XCTestCase {

    func testLaunchdIsSystem() {
        XCTAssertTrue(SystemProcessChecker.isSystemProcess(pid: 1))
    }

    func testCurrentProcessIsNotSystem() {
        XCTAssertFalse(SystemProcessChecker.isSystemProcess(pid: Int(ProcessInfo.processInfo.processIdentifier)))
    }

    func testInvalidPidIsNotSystem() {
        XCTAssertFalse(SystemProcessChecker.isSystemProcess(pid: 0))
        XCTAssertFalse(SystemProcessChecker.isSystemProcess(pid: -5))
    }
}
