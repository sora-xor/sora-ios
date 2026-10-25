import MocksBasket
import XCTest

@testable import SSFStorageQueryKit

final class JSONRPCWorkerTests: XCTestCase {
    func testTimeout() async throws {
        let connection = JSONRPCEngineMock()
        let worker = JSONRPCWorker<String, String>(
            engine: connection,
            method: "timeout",
            parameters: "params",
            timeout: TimeInterval(0.1)
        )

        do {
            let _: String = try await worker.performCall()
            XCTFail("method should to throw timeout error")
        } catch {
            XCTAssertTrue(error is JSONRPCWorkerContinuationError)
        }
    }

    func testResult() async throws {
        let connection = JSONRPCEngineMock()
        connection.completionResult = "success"
        let worker = JSONRPCWorker<String, String>(
            engine: connection,
            method: "timeout",
            parameters: "params",
            timeout: TimeInterval(0.1)
        )

        let success: String = try await worker.performCall()
        XCTAssertEqual(success, "success")
    }
}
