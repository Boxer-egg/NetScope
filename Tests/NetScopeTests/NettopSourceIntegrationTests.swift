import XCTest
@testable import NetScope

final class NettopSourceIntegrationTests: XCTestCase {

    func testSourceEmitsUpdatesFromLiveNettop() async throws {
        let source = NettopConnectionSource(interval: 1.0)
        let expectation = XCTestExpectation(description: "nettop source emits connections")
        expectation.assertForOverFulfill = false

        source.onUpdate = { connections in
            if !connections.isEmpty {
                expectation.fulfill()
            }
        }
        source.start()
        defer { source.stop() }

        await fulfillment(of: [expectation], timeout: 8)
    }
}
