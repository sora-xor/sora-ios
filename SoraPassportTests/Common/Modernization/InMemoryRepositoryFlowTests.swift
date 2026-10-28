// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import RobinHood
import XCTest
@testable import SoraPassport

final class InMemoryRepositoryFlowTests: XCTestCase {
    private struct Record: RobinHood.Identifiable, Equatable { let identifier: String; let value: Int }
    private enum Failure: Swift.Error { case rejected }
    private func run<T>(_ op: BaseOperation<T>) throws -> T {
        op.start(); return try XCTUnwrap(op.result).get()
    }
    private func fixture() throws -> InMemoryDataProviderRepository<Record> {
        let repo = InMemoryDataProviderRepository<Record>()
        try run(repo.replaceOperation { [.init(identifier: "a", value: 1), .init(identifier: "b", value: 2), .init(identifier: "c", value: 3)] })
        return repo
    }
    func testFetchByIdentifiersReturnsOnlyRequestedRecords() throws {
        let repo = try fixture()
        let result = try run(repo.fetchOperation(by: { ["c", "a"] }, options: RepositoryFetchOptions()))
        XCTAssertEqual(Set(result.map(\.identifier)), Set(["a", "c"]))
    }
    func testFetchByIdentifiersSkipsMissingRecords() throws {
        let repo = try fixture()
        let result = try run(repo.fetchOperation(by: { ["missing", "b"] }, options: RepositoryFetchOptions()))
        XCTAssertEqual(result, [.init(identifier: "b", value: 2)])
    }
    func testEmptyIdentifierRequestReturnsNoRecords() throws {
        let repo = try fixture()
        XCTAssertTrue(try run(repo.fetchOperation(by: { [String]() }, options: RepositoryFetchOptions())).isEmpty)
    }
    func testIdentifierProviderFailurePropagates() throws {
        let repo = try fixture()
        XCTAssertThrowsError(try run(repo.fetchOperation(by: { () throws -> [String] in throw Failure.rejected }, options: RepositoryFetchOptions()))) { XCTAssertTrue($0 is Failure) }
    }
    func testIdentifierProviderIsEvaluatedAtExecutionTime() throws {
        let repo = try fixture(); var ids = ["a"]
        let operation = repo.fetchOperation(by: { ids }, options: RepositoryFetchOptions()); ids = ["b"]
        XCTAssertEqual(try run(operation), [.init(identifier: "b", value: 2)])
    }
    func testSingleRecordReadReturnsLatestReplacement() throws {
        let repo = try fixture()
        try run(repo.saveOperation({ [.init(identifier: "a", value: 4)] }, { [] }))
        XCTAssertEqual(try run(repo.fetchOperation(by: { "a" }, options: RepositoryFetchOptions()))?.value, 4)
        XCTAssertEqual(try run(repo.fetchCountOperation()), 3)
    }
    func testMissingSingleRecordReturnsNil() throws {
        let repo = try fixture()
        XCTAssertNil(try run(repo.fetchOperation(by: { "missing" }, options: RepositoryFetchOptions())))
    }
    func testSingleIdentifierProviderFailurePropagates() throws {
        let repo = try fixture()
        XCTAssertThrowsError(try run(repo.fetchOperation(by: { () throws -> String in throw Failure.rejected }, options: RepositoryFetchOptions())))
    }
    func testSaveAppliesDeletionAfterUpdatesAtomically() throws {
        let repo = try fixture()
        try run(repo.saveOperation({ [.init(identifier: "d", value: 4), .init(identifier: "b", value: 8)] }, { ["a", "b"] }))
        XCTAssertEqual(Set(try run(repo.fetchAllOperation(with: RepositoryFetchOptions())).map(\.identifier)), Set(["c", "d"]))
    }
    func testFailedDeleteProviderCannotPartiallyCommitUpdates() throws {
        let repo = try fixture()
        XCTAssertThrowsError(try run(repo.saveOperation({ [.init(identifier: "a", value: 9)] }, { throw Failure.rejected })))
        XCTAssertEqual(try run(repo.fetchOperation(by: { "a" }, options: RepositoryFetchOptions()))?.value, 1)
    }
    func testFailedUpdateProviderCannotApplyDeletions() throws {
        let repo = try fixture()
        XCTAssertThrowsError(try run(repo.saveOperation({ throw Failure.rejected }, { ["a"] })))
        XCTAssertEqual(try run(repo.fetchCountOperation()), 3)
    }
    func testBatchSavePreservesAtomicFailureBehavior() throws {
        let repo = try fixture()
        XCTAssertThrowsError(try run(repo.saveBatchOperation({ [.init(identifier: "a", value: 9)] }, { throw Failure.rejected })))
        XCTAssertEqual(try run(repo.fetchOperation(by: { "a" }, options: RepositoryFetchOptions()))?.value, 1)
    }
    func testBatchSaveUpsertsAndDeletes() throws {
        let repo = try fixture()
        try run(repo.saveBatchOperation({ [.init(identifier: "a", value: 7)] }, { ["b", "c"] }))
        XCTAssertEqual(try run(repo.fetchAllOperation(with: RepositoryFetchOptions())), [.init(identifier: "a", value: 7)])
    }
    func testReplaceClearsPreviousRecordsAndUsesLastDuplicate() throws {
        let repo = try fixture()
        try run(repo.replaceOperation { [.init(identifier: "z", value: 8), .init(identifier: "z", value: 9)] })
        XCTAssertEqual(try run(repo.fetchAllOperation(with: RepositoryFetchOptions())), [.init(identifier: "z", value: 9)])
    }
    func testFailedReplacementPreservesExistingRecords() throws {
        let repo = try fixture()
        XCTAssertThrowsError(try run(repo.replaceOperation { throw Failure.rejected }))
        XCTAssertEqual(try run(repo.fetchCountOperation()), 3)
    }
    func testDeleteAllIsIdempotentAndAllowsSubsequentInsert() throws {
        let repo = try fixture(); try run(repo.deleteAllOperation()); try run(repo.deleteAllOperation())
        XCTAssertEqual(try run(repo.fetchCountOperation()), 0)
        try run(repo.saveOperation({ [.init(identifier: "new", value: 1)] }, { [] }))
        XCTAssertEqual(try run(repo.fetchCountOperation()), 1)
    }
    func testConcurrentDisjointWritesAreNotLost() async throws {
        let repo = InMemoryDataProviderRepository<Record>(); let queue = OperationQueue()
        let done = expectation(description: "All writes committed"); done.expectedFulfillmentCount = 100
        for i in 0..<100 {
            let operation = repo.saveOperation({ [.init(identifier: String(i), value: i)] }, { [] })
            operation.completionBlock = { done.fulfill() }; queue.addOperation(operation)
        }
        await fulfillment(of: [done], timeout: 3)
        XCTAssertEqual(try run(repo.fetchCountOperation()), 100)
    }
}
