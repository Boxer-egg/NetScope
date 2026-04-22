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

        source.onUpdate = { _ in
            expectation.fulfill()
        }

        source.start()
        wait(for: [expectation], timeout: 2.0)
        source.stop()
    }
}
