// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import Foundation
import RobinHood
import SSFUtils
import XCTest
@testable import SoraPassport

@MainActor
final class LPFeeServiceFlowTests: XCTestCase {
    private func drain(_ manager: LPFlowManager) async {
        for _ in 0..<100 {
            if manager.pending == 0 { await Task.yield(); if manager.pending == 0 { return } }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("LP fee operation graph did not finish")
    }
    func testMissingChainDependenciesDoNotCrashOrInventAnXSTFee() {
        let manager = LPFlowManager(); let service = LPFeeService(engine: nil, runtime: nil, operationManager: manager)
        XCTAssertEqual(service.getLpfee(with: 0), "0.3"); XCTAssertEqual(service.getLpfee(with: 1), "")
        XCTAssertEqual(manager.enqueues, 0)
    }
    func testReadUsesExactOnChainFeeAndStorageKey() async throws {
        let engine = LPFlowEngine(); engine.raw = 60_000_000_000_000
        let manager = LPFlowManager(); let runtime = LPFlowRuntime()
        let service = LPFeeService(engine: engine, runtime: runtime, operationManager: manager)
        await drain(manager)
        XCTAssertEqual(service.getLpfee(with: 1), "0.006"); XCTAssertEqual(service.getLpfee(with: 0), "0.3")
        XCTAssertEqual(runtime.fetches, 0); XCTAssertEqual(engine.methods, [SoraPassport.RPCMethod.getStorage])
        XCTAssertEqual(engine.parameters, [[try StorageKeyFactory().xstPoolBaseFee().toHex(includePrefix: true)]])
    }
    func testExplicitZeroFeeIsNotTreatedAsMissing() async {
        let engine = LPFlowEngine(); engine.raw = 0; let runtime = LPFlowRuntime(); let manager = LPFlowManager()
        let service = LPFeeService(engine: engine, runtime: runtime, operationManager: manager)
        await drain(manager); XCTAssertEqual(service.getLpfee(with: 1), "0"); XCTAssertEqual(runtime.fetches, 0)
    }
    func testAbsentFeeRequestsRuntimeFallback() async {
        let engine = LPFlowEngine(); engine.raw = nil; let runtime = LPFlowRuntime(); let manager = LPFlowManager()
        let service = LPFeeService(engine: engine, runtime: runtime, operationManager: manager)
        await drain(manager); XCTAssertEqual(runtime.fetches, 1); XCTAssertEqual(service.getLpfee(with: 1), "")
    }
    func testFailedFeeReadRequestsRuntimeFallback() async {
        let engine = LPFlowEngine(); engine.failure = true; let runtime = LPFlowRuntime(); let manager = LPFlowManager()
        let service = LPFeeService(engine: engine, runtime: runtime, operationManager: manager)
        await drain(manager); XCTAssertEqual(runtime.fetches, 1); XCTAssertEqual(service.getLpfee(with: 1), "")
    }
    func testMalformedFeeReadRequestsRuntimeFallback() async {
        let engine = LPFlowEngine(); engine.malformed = true; let runtime = LPFlowRuntime(); let manager = LPFlowManager()
        let service = LPFeeService(engine: engine, runtime: runtime, operationManager: manager)
        await drain(manager); XCTAssertEqual(runtime.fetches, 1); XCTAssertEqual(service.getLpfee(with: 1), "")
    }
    func testMissingConnectionStillAttemptsAvailableRuntimeFallback() async {
        let runtime = LPFlowRuntime(); let manager = LPFlowManager()
        let service = LPFeeService(engine: nil, runtime: runtime, operationManager: manager)
        await drain(manager); XCTAssertEqual(runtime.fetches, 1); XCTAssertEqual(service.getLpfee(with: 1), "")
    }
    func testCompletedFeeReadDoesNotRetainItsService() async {
        let engine = LPFlowEngine(); let manager = LPFlowManager()
        var service: LPFeeService? = LPFeeService(engine: engine, runtime: nil, operationManager: manager)
        weak var weakService = service
        await drain(manager); service = nil; XCTAssertNil(weakService)
    }
    func testOtherDEXIdentifiersUseTheXSTSchedule() async {
        let engine = LPFlowEngine(); engine.raw = 123_000_000_000_000; let manager = LPFlowManager()
        let service = LPFeeService(engine: engine, runtime: nil, operationManager: manager)
        await drain(manager); XCTAssertEqual(service.getLpfee(with: 1), "0.0123"); XCTAssertEqual(service.getLpfee(with: UInt32.max), "0.0123")
    }
}
private enum LPFlowFailure: Swift.Error { case offline }
private final class LPFlowManager: OperationManagerProtocol {
    let queue = OperationQueue(); var enqueues = 0
    private let lock = NSLock(); private var pendingCount = 0
    var pending: Int { lock.lock(); defer { lock.unlock() }; return pendingCount }
    func enqueue(operations: [Operation], in mode: OperationMode) {
        lock.lock(); enqueues += 1; pendingCount += operations.count; lock.unlock()
        for operation in operations {
            let existing = operation.completionBlock
            operation.completionBlock = { [self] in existing?(); lock.lock(); pendingCount -= 1; lock.unlock() }
        }
        queue.addOperations(operations, waitUntilFinished: false)
    }
}
private final class LPFlowRuntime: SoraPassport.RuntimeCodingServiceProtocol {
    var fetches = 0
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        fetches += 1; return ClosureOperation { throw LPFlowFailure.offline }
    }
}
private final class LPFlowEngine: JSONRPCEngine {
    var url: URL?; var pendingEngineRequests: [JSONRPCRequest] { [] }
    var raw: BigUInt? = 1, failure = false, malformed = false, methods = [String](), parameters = [[String]]()
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Swift.Error>) -> Void)?) throws -> UInt16 {
        methods.append(method); parameters.append(try JSONDecoder().decode([String].self, from: JSONEncoder().encode(params)))
        let answer = Result<T, Swift.Error> {
            if failure { throw LPFlowFailure.offline }
            let value: Any
            if malformed { value = "0x01" }
            else if let raw { let bytes = Array(raw.serialize().reversed()); value = Data(bytes + Array(repeating: 0, count: 16 - bytes.count)).toHex(includePrefix: true) }
            else { value = NSNull() }
            return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]))
        }
        DispatchQueue.global().async { closure?(answer) }; return 1
    }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Swift.Error, Bool) -> Void) throws -> UInt16 { XCTFail("Unexpected subscription"); throw LPFlowFailure.offline }
    func cancelForIdentifier(_ identifier: UInt16) {}; func generateRequestId() -> UInt16 { 1 }; func addSubscription(_ subscription: JSONRPCSubscribing) {}; func connectIfNeeded() {}; func disconnectIfNeeded() {}; func unsubsribe(_ identifier: UInt16) throws {}
}
