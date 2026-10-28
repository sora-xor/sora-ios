// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraKeystore
import XCTest

@testable import SoraPassport

/// Exercises production referral operations with a recording builder service.
/// No signer or transport is invoked; all keys are held only in memory.
@MainActor
final class ReferralSubmissionFactoryTests: XCTestCase {
  private let expectedHash = "0x" + String(repeating: "0a", count: 32)
  private func make(_ service: ReferralFactoryExtrinsics) throws -> ReferralsOperationFactory {
    let key = Data(repeating: 0x42, count: 32)
    let account = AccountItem(
      address: try SS58AddressFactory().addressFromAccountId(
        data: key, type: SoraPassport.Chain.sora.addressType()),
      cryptoType: .sr25519, networkType: SoraPassport.Chain.sora.addressType(),
      username: "Referral fixture", publicKeyData: key,
      settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0,
      isSelected: true)
    return ReferralsOperationFactory(
      settings: InMemorySettingsManager(), keychain: InMemoryKeychain(),
      engine: ReferralFactoryEngine(),
      runtimeRegistry: ReferralFactoryRuntime(), selectedAccount: account, extrinsicService: service
    )
  }
  private func run(_ op: BaseOperation<String>) async throws -> String {
    let done = expectation(description: "referral operation")
    op.completionBlock = { done.fulfill() }
    let queue = OperationQueue()
    queue.qualityOfService = .userInitiated
    queue.addOperation(op)
    await fulfillment(of: [done], timeout: 3)
    return try XCTUnwrap(op.result).get()
  }
  private func call<T: Decodable>(_ service: ReferralFactoryExtrinsics, as type: T.Type) throws -> T
  {
    try XCTUnwrap(service.builders.first?.calls.first).map(to: T.self)
  }
  func testSetReferrerUsesTheExactPublicAccountBytesAndModule() async throws {
    let s = ReferralFactoryExtrinsics()
    let f = try make(s)
    let result = try await run(
      f.createExtrinsicSetReferrerOperation(with: "0x" + String(repeating: "ab", count: 32)))
    XCTAssertEqual(result, expectedHash)
    let c: RuntimeCall<SetReferrerCall> = try call(s, as: RuntimeCall<SetReferrerCall>.self)
    XCTAssertEqual(c.moduleName, "Referrals")
    XCTAssertEqual(c.callName, "set_referrer")
    XCTAssertEqual(c.args.referrer, Data(repeating: 0xab, count: 32))
  }
  func testSetReferrerFailsOnMalformedHexWithoutBuildingACall() async throws {
    let s = ReferralFactoryExtrinsics()
    let f = try make(s)
    do {
      _ = try await run(f.createExtrinsicSetReferrerOperation(with: "not hex"))
      XCTFail("Malformed key accepted")
    } catch {
      XCTAssertEqual(s.submitCount, 1)
      XCTAssertTrue(s.builders.isEmpty)
    }
  }
  func testReservePreservesAllAtomicDigits() async throws {
    let amount = BigUInt("340282366920938463463374607431768211455")
    let s = ReferralFactoryExtrinsics()
    let f = try make(s)
    let result = try await run(f.createExtrinsicReserveReferralBalanceOperation(with: amount))
    XCTAssertEqual(result, expectedHash)
    let c: RuntimeCall<ReferralBalanceCall> = try call(s, as: RuntimeCall<ReferralBalanceCall>.self)
    XCTAssertEqual(c.moduleName, "Referrals")
    XCTAssertEqual(c.callName, "reserve")
    XCTAssertEqual(c.args.balance, amount)
  }
  func testUnreservePreservesAllAtomicDigits() async throws {
    let amount = BigUInt("340282366920938463463374607431768211455")
    let s = ReferralFactoryExtrinsics()
    let f = try make(s)
    let result = try await run(f.createExtrinsicUnreserveReferralBalanceOperation(with: amount))
    XCTAssertEqual(result, expectedHash)
    let c: RuntimeCall<ReferralBalanceCall> = try call(s, as: RuntimeCall<ReferralBalanceCall>.self)
    XCTAssertEqual(c.moduleName, "Referrals")
    XCTAssertEqual(c.callName, "unreserve")
    XCTAssertEqual(c.args.balance, amount)
  }
  func testReserveKeepsOneAtomicUnitRatherThanRoundingToZero() async throws {
    let s = ReferralFactoryExtrinsics()
    let f = try make(s)
    _ = try await run(f.createExtrinsicReserveReferralBalanceOperation(with: 1))
    let c: RuntimeCall<ReferralBalanceCall> = try call(s, as: RuntimeCall<ReferralBalanceCall>.self)
    XCTAssertEqual(c.args.balance, 1)
  }
  func testUnreserveKeepsOneAtomicUnitRatherThanRoundingToZero() async throws {
    let s = ReferralFactoryExtrinsics()
    let f = try make(s)
    _ = try await run(f.createExtrinsicUnreserveReferralBalanceOperation(with: 1))
    let c: RuntimeCall<ReferralBalanceCall> = try call(s, as: RuntimeCall<ReferralBalanceCall>.self)
    XCTAssertEqual(c.args.balance, 1)
  }
  private func expectFailure(_ kind: Int) async throws {
    let s = ReferralFactoryExtrinsics()
    s.failure = ReferralFactoryBoundaryError.offline
    let f = try make(s)
    let op = operation(kind, factory: f)
    do {
      _ = try await run(op)
      XCTFail("Failed submission became success")
    } catch { XCTAssertTrue(error is ReferralFactoryBoundaryError) }
    XCTAssertEqual(s.submitCount, 1)
  }
  func testSetReferrerPreservesSubmissionFailure() async throws { try await expectFailure(0) }
  func testReservePreservesSubmissionFailure() async throws { try await expectFailure(1) }
  func testUnreservePreservesSubmissionFailure() async throws { try await expectFailure(2) }
  private func operation(_ kind: Int, factory: ReferralsOperationFactory) -> BaseOperation<String> {
    switch kind {
    case 0:
      return factory.createExtrinsicSetReferrerOperation(with: String(repeating: "42", count: 32))
    case 1: return factory.createExtrinsicReserveReferralBalanceOperation(with: 1)
    default: return factory.createExtrinsicUnreserveReferralBalanceOperation(with: 1)
    }
  }
  private func cancellation(_ kind: Int) async throws {
    let s = ReferralFactoryExtrinsics()
    let f = try make(s)
    let op = operation(kind, factory: f)
    op.cancel()
    op.start()
    XCTAssertTrue(op.isCancelled)
    XCTAssertTrue(op.isFinished)
    XCTAssertEqual(s.submitCount, 0)
  }
  func testCancelledReferrerOperationDoesNotReachTheSubmissionService() async throws {
    try await cancellation(0)
  }
  func testCancelledReserveOperationDoesNotReachTheSubmissionService() async throws {
    try await cancellation(1)
  }
  func testCancelledUnreserveOperationDoesNotReachTheSubmissionService() async throws {
    try await cancellation(2)
  }
  private func releasedFactory(_ kind: Int) async throws {
    var service: ReferralFactoryExtrinsics? = ReferralFactoryExtrinsics()
    weak var observed = service
    var factory: ReferralsOperationFactory? = try make(service!)
    let op = operation(kind, factory: factory!)
    service = nil
    factory = nil
    // A returned operation must own the service it needs. Assert this before
    // starting it so a regression cannot leave a worker waiting for 60 seconds.
    _ = try XCTUnwrap(observed, "A queued operation lost its required submission service")
    let result = try await run(op)
    XCTAssertEqual(result, expectedHash)
  }
  func testQueuedReferrerOperationOutlivesItsFactory() async throws { try await releasedFactory(0) }
  func testQueuedReserveOperationOutlivesItsFactory() async throws { try await releasedFactory(1) }
  func testQueuedUnreserveOperationOutlivesItsFactory() async throws {
    try await releasedFactory(2)
  }
  func testSubmissionUsesTheCallerKeystoreWithoutSigningAtFactoryTime() throws {
    let s = ReferralFactoryExtrinsics()
    let f = try make(s)
    _ = f.createExtrinsicReserveReferralBalanceOperation(with: 1)
    XCTAssertEqual(s.submitCount, 0)
    XCTAssertTrue(s.builders.isEmpty)
  }
}

private enum ReferralFactoryBoundaryError: Error { case offline, unexpected }
private final class ReferralFactoryCall: CancellableCall {
  var cancelled = false
  func cancel() { cancelled = true }
}
private final class ReferralFactoryExtrinsics: ExtrinsicServiceProtocol {
  var rawFee = "7"
  var failure: Error?
  var builders: [ReferralFactoryBuilder] = []
  var estimateCount = 0
  var prepareCount = 0
  var submitCount = 0
  var preparedSubmitCount = 0
  var cancelAfterPrepare = false
  var prepared: PreparedExtrinsicSubmission?
  let call = ReferralFactoryCall()
  private func record(_ closure: ExtrinsicBuilderClosure) throws {
    let builder = ReferralFactoryBuilder()
    _ = try closure(builder)
    builders.append(builder)
    if let failure { throw failure }
  }
  func estimateFee(
    _ closure: @escaping ExtrinsicBuilderClosure, runningIn queue: DispatchQueue,
    completion: @escaping EstimateFeeClosure
  ) {
    estimateCount += 1
    do {
      try record(closure)
      completion(.success(rawFee))
    } catch { completion(.failure(error)) }
  }
  func prepareAndEstimateFee(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    preSigningValidation: @escaping () throws -> Void, runningIn queue: DispatchQueue,
    completion: @escaping (Result<PreparedExtrinsicFeeQualification, Error>) -> Void
  ) -> CancellableCall {
    prepareCount += 1
    do {
      try preSigningValidation()
      try record(closure)
      let bytes = Data([1, 2, 3, 4])
      let result = PreparedExtrinsicSubmission(
        data: bytes, hash: try bytes.blake2b32().toHex(includePrefix: true))
      prepared = result
      if cancelAfterPrepare { withUnsafeCurrentTask { $0?.cancel() } }
      completion(.success(PreparedExtrinsicFeeQualification(prepared: result, rawFee: rawFee)))
    } catch { completion(.failure(error)) }
    return call
  }
  func prepareAndEstimateFee(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    lifecycleLease: WalletLifecycleLease?,
    runtimeValidation: ((RuntimeCoderFactoryProtocol) throws -> Void)?,
    finalizedHeadValidation: ((String) throws -> Void)?,
    preSigningValidation: @escaping () throws -> Void,
    runningIn queue: DispatchQueue,
    completion: @escaping (Result<PreparedExtrinsicFeeQualification, Error>) -> Void
  ) -> CancellableCall {
    XCTFail("Unexpected lifecycle preparation")
    completion(.failure(ReferralFactoryBoundaryError.unexpected))
    return call
  }
  func submit(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    runningIn queue: DispatchQueue,
    completion: @escaping ExtrinsicSubmitClosure
  ) {
    submitCount += 1
    do {
      try record(closure)
      completion(
        .success("0x" + String(repeating: "0a", count: 32)),
        "0x" + String(repeating: "0a", count: 32), nil)
    } catch { completion(.failure(error), nil, nil) }
  }
  func submit(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    lifecycleLease: WalletLifecycleLease?,
    runningIn queue: DispatchQueue, completion: @escaping ExtrinsicSubmitClosure
  ) {
    XCTFail("Unexpected lifecycle submission")
    completion(.failure(ReferralFactoryBoundaryError.unexpected), nil, nil)
  }
  func prepare(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    runningIn queue: DispatchQueue,
    completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void
  ) {
    XCTFail("Unexpected unqualified preparation")
    completion(.failure(ReferralFactoryBoundaryError.unexpected))
  }
  func prepare(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    lifecycleLease: WalletLifecycleLease?,
    runtimeValidation: ((RuntimeCoderFactoryProtocol) throws -> Void)?,
    preSigningValidation: (() throws -> Void)?,
    runningIn queue: DispatchQueue,
    completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void
  ) {
    XCTFail("Unexpected lifecycle preparation")
    completion(.failure(ReferralFactoryBoundaryError.unexpected))
  }
  func submitPrepared(
    _ prepared: PreparedExtrinsicSubmission, retainingTransportWitness: Bool,
    expectedRawFee: String,
    preTransportValidation: @escaping () throws -> Void, runningIn queue: DispatchQueue,
    completion: @escaping (Result<String, Error>) -> Void
  ) -> CancellableCall {
    preparedSubmitCount += 1
    XCTFail("Unexpected transport")
    completion(.failure(ReferralFactoryBoundaryError.unexpected))
    return call
  }
}
private final class ReferralFactoryBuilder: SoraPassport.ExtrinsicBuilderProtocol {
  var calls: [JSON] = []
  var atomicSelections: [Bool] = []
  func with<A: Codable>(address: A) throws -> Self {
    XCTFail("Unexpected address binding")
    return self
  }
  func with(nonce: UInt32) -> Self {
    XCTFail("Unexpected nonce")
    return self
  }
  func with(era: Era, blockHash: String) -> Self {
    XCTFail("Unexpected era")
    return self
  }
  func with(tip: BigUInt) -> Self {
    XCTFail("Unexpected tip")
    return self
  }
  func with(shouldUseAtomicBatch: Bool) -> Self {
    atomicSelections.append(shouldUseAtomicBatch)
    return self
  }
  func adding<T: RuntimeCallable>(call: T) throws -> Self {
    let encoded = try JSONEncoder.scaleCompatible().encode(
      SoraPassport.EncodingContainer(value: call))
    calls.append(
      try JSONDecoder.scaleCompatible(snakeCase: false).decode(
        SoraPassport.JsonContainer.self, from: encoded
      ).value)
    return self
  }
  func adding(rawCall: Data) throws -> Self {
    XCTFail("Unexpected raw call")
    throw ReferralFactoryBoundaryError.unexpected
  }
  func signing(
    by signer: (Data) throws -> Data, of type: SoraPassport.CryptoType,
    using encoder: DynamicScaleEncoding,
    metadata: RuntimeMetadata
  ) throws -> Self {
    XCTFail("Unexpected signing")
    throw ReferralFactoryBoundaryError.unexpected
  }
  func buildExtrinsic(metadata: RuntimeMetadata) throws -> Extrinsic {
    XCTFail("Unexpected extrinsic build")
    throw ReferralFactoryBoundaryError.unexpected
  }
  func build(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws -> Data {
    throw ReferralFactoryBoundaryError.unexpected
  }
  func buildSignature(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws
    -> Data
  { throw ReferralFactoryBoundaryError.unexpected }
}

private final class ReferralFactoryRuntime: RuntimeProviderProtocol {
  let chainId = PIIndexerClient.soraMainnetGenesis
  var snapshot: RuntimeSnapshot? { nil }
  var reads = 0
  func setup() {}
  func setupHot() {}
  func replaceTypesUsage(_ usage: ChainModel.TypesUsage) {}
  func cleanup() {}
  func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: RuntimeMetadataClosure?)
    -> BaseOperation<RuntimeCoderFactoryProtocol>
  {
    reads += 1
    return ClosureOperation { throw CancellationError() }
  }
}

private final class ReferralFactoryEngine: JSONRPCEngine {
  var calls = 0
  var url: URL?
  var pendingEngineRequests: [JSONRPCRequest] { [] }
  func callMethod<P: Codable, T: Decodable>(
    _ method: String, params: P?, options: JSONRPCOptions,
    completion closure: ((Result<T, Error>) -> Void)?
  ) throws -> UInt16 {
    calls += 1
    if method.contains("submit") { XCTFail("No transport is permitted during tab construction") }
    throw URLError(.notConnectedToInternet)
  }
  func subscribe<P: Codable, T: Decodable>(
    _ method: String, params: P?, updateClosure: @escaping (T) -> Void,
    failureClosure: @escaping (Error, Bool) -> Void
  ) throws -> UInt16 { throw URLError(.notConnectedToInternet) }
  func cancelForIdentifier(_ identifier: UInt16) {}
  func generateRequestId() -> UInt16 { 1 }
  func addSubscription(_ subscription: JSONRPCSubscribing) {}
  func connectIfNeeded() {}
  func disconnectIfNeeded() {}
  func unsubsribe(_ identifier: UInt16) throws {}
}
