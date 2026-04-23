import XCTest
@testable import NetScope

final class NetworkStatisticsSourceTests: XCTestCase {

    func testSourceExistsAndHasCorrectDisplayName() {
        let source = NetworkStatisticsSource()
        XCTAssertEqual(source.displayName, "NetworkStatistics")
    }

    func testStartStopDoesNotCrashAndReturnsConnections() {
        let source = NetworkStatisticsSource()
        let expectation = self.expectation(description: "onUpdate called with connections")

        source.onUpdate = { connections in
            expectation.fulfill()
        }

        source.start()
        wait(for: [expectation], timeout: 5.0)
        source.stop()
    }
}
