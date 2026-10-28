// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import IrohaCrypto
import RobinHood
import SSFUtils
import XCTest

@testable import SoraPassport

@MainActor
final class FeeProviderBehaviorTests: XCTestCase {
  private var previous: AccountItem?
  private var account: AccountItem!
  override func setUpWithError() throws {
    previous = SelectedWalletSettings.shared.currentAccount
    let key = Data(repeating: 3, count: 32)
    account = AccountItem(
      address: try SS58AddressFactory().address(
        fromAccountId: key, type: SNAddressType(chain: .sora)), cryptoType: .sr25519,
      networkType: 69, username: "Fee fixture", publicKeyData: key,
      settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0,
      isSelected: true)
    SelectedWalletSettings.shared.commitInternalValue(account)
  }
  override func tearDown() {
    SelectedWalletSettings.shared.commitInternalValue(previous)
    super.tearDown()
  }
  private func make() -> (FeeProvider, FeeFixtureService) {
    let service = FeeFixtureService()
    service.rawFee = "1234567890123456789"
    return (FeeProvider(account: account, serviceFactory: { _ in service }), service)
  }
  private func call<T: Codable>(_ service: FeeFixtureService, _ type: T.Type, index: Int = 0) throws
    -> RuntimeCall<T>
  { try XCTUnwrap(service.builders.first?.calls[index]).map(to: RuntimeCall<T>.self) }
  func testTransferEstimateUsesBoundSenderAndZeroProbeAmount() async throws {
    let (p, s) = make()
    let value = await p.getFee(for: TransactionType.outgoing)
    XCTAssertEqual(value, Decimal(string: "1.234567890123456789"))
    let c = try call(s, SoraTransferCall.self)
    XCTAssertEqual(c.args.receiver, account.publicKeyData)
    XCTAssertEqual(c.args.assetId.value, WalletAssetId.xor.rawValue)
    XCTAssertEqual(c.args.amount, 0)
    XCTAssertEqual(s.submitCount, 0)
  }
  func testSelectedWalletChangeCannotAlterTheBoundFeeAccount() async throws {
    let (p, s) = make()
    SelectedWalletSettings.shared.commitInternalValue(nil)
    _ = await p.getFee(for: TransactionType.outgoing)
    XCTAssertEqual(try call(s, SoraTransferCall.self).args.receiver, account.publicKeyData)
  }
  func testSwapEstimateUsesBothDistinctAssetsAndDesiredInput() async throws {
    let (p, s) = make()
    _ = await p.getFee(for: TransactionType.swap)
    let c = try call(s, SwapCall.self)
    XCTAssertEqual(c.args.inputAssetId.value, WalletAssetId.xor.rawValue)
    XCTAssertEqual(c.args.outputAssetId.value, WalletAssetId.val.rawValue)
    XCTAssertEqual(c.args.amount[.desiredInput]?.desired, 0)
    XCTAssertEqual(c.args.amount[.desiredInput]?.slip, 0)
  }
  func testExistingPoolDepositEstimateHasOneCall() async throws {
    let (p, s) = make()
    _ = await p.getFee(for: TransactionType.liquidityAdd)
    let c = try call(s, DepositLiquidityCall.self)
    XCTAssertEqual(c.args.assetA.value, WalletAssetId.xor.rawValue)
    XCTAssertEqual(c.args.assetB.value, WalletAssetId.val.rawValue)
    XCTAssertEqual(c.args.desiredA, 1)
    XCTAssertEqual(c.args.minB, 1)
    XCTAssertEqual(s.builders[0].calls.count, 1)
  }
  func testFirstDepositEstimatesAnAtomicInitializeThenDeposit() async throws {
    let (p, s) = make()
    _ = await p.getFee(for: TransactionType.liquidityAddToExistingPoolFirstTime)
    XCTAssertEqual(s.builders[0].atomicSelections, [true])
    XCTAssertEqual(try call(s, InitializePoolCall.self).callName, "initialize_pool")
    XCTAssertEqual(try call(s, DepositLiquidityCall.self, index: 1).callName, "deposit_liquidity")
  }
  func testNewPoolEstimatesAnAtomicRegisterInitializeDeposit() async throws {
    let (p, s) = make()
    _ = await p.getFee(for: TransactionType.liquidityAddNewPool)
    XCTAssertEqual(s.builders[0].atomicSelections, [true])
    XCTAssertEqual(try call(s, PairRegisterCall.self).callName, "register")
    XCTAssertEqual(try call(s, InitializePoolCall.self, index: 1).callName, "initialize_pool")
    XCTAssertEqual(try call(s, DepositLiquidityCall.self, index: 2).callName, "deposit_liquidity")
  }
  func testWithdrawalEstimateUsesDistinctBaseAndTargetAssets() async throws {
    let (p, s) = make()
    _ = await p.getFee(for: TransactionType.liquidityRemoval)
    let c = try call(s, WithdrawLiquidityCall.self)
    XCTAssertEqual(c.args.assetA.value, WalletAssetId.xor.rawValue)
    XCTAssertEqual(c.args.assetB.value, WalletAssetId.val.rawValue)
    XCTAssertEqual(c.args.assetDesired, 1)
  }
  func testReferralEstimateUsesTheBoundAccountAsTheProbeReferrer() async throws {
    let (p, s) = make()
    _ = await p.getFee(for: TransactionType.referral)
    XCTAssertEqual(try call(s, SetReferrerCall.self).args.referrer, account.publicKeyData)
  }
  func testUnsupportedHistoryTypesDoNotAskForAChainFee() async {
    for type in [
      TransactionType.incoming, .reward, .slash, .migration, .extrinsic, .demeterDeposit,
      .demeterWithdraw, .demeterClaimReward,
    ] {
      let (p, s) = make()
      let value = await p.getFee(for: type)
      XCTAssertEqual(value, 0)
      XCTAssertEqual(s.estimateCount, 0)
    }
  }
  func testRuntimeCallEstimatePreservesTheActualCall() async throws {
    let (p, s) = make()
    let original = try SubstrateCallFactory().reserveReferralBalance(balance: 42)
    let value = await p.getFee(for: original)
    XCTAssertEqual(value, Decimal(string: "1.234567890123456789"))
    XCTAssertEqual(s.builders[0].calls.count, 1)
    let json = try JSONEncoder.scaleCompatible().encode(
      SoraPassport.EncodingContainer(value: original))
    let expected = try JSONDecoder.scaleCompatible(snakeCase: false).decode(
      SoraPassport.JsonContainer.self, from: json
    ).value
    XCTAssertEqual(s.builders[0].calls[0], expected)
  }
  func testMissingAccountNeverConstructsAnExtrinsicService() async {
    var calls = 0
    let p = FeeProvider(
      account: nil,
      serviceFactory: { _ in
        calls += 1
        return nil
      })
    let value = await p.getFee(for: TransactionType.outgoing)
    XCTAssertEqual(value, 0)
    XCTAssertEqual(calls, 0)
  }
  func testUnavailableServiceCompletesTheFeeRead() async {
    let p = FeeProvider(account: account, serviceFactory: { _ in nil })
    let value = await p.getFee(for: TransactionType.outgoing)
    XCTAssertEqual(value, 0)
  }
  func testMalformedFeeDoesNotTurnIntoAPartiallyParsedAmount() async {
    for raw in ["garbage", "1trailing", "-1", "1.5"] {
      let (p, s) = make()
      s.rawFee = raw
      let value = await p.getFee(for: TransactionType.swap)
      XCTAssertEqual(value, 0)
    }
  }
  func testNodeFailureCompletesTheTransactionTypeRead() async {
    let (p, s) = make()
    s.failure = FeeFixtureFailure.offline
    let value = await p.getFee(for: TransactionType.swap)
    XCTAssertEqual(value, 0)
  }
  func testNodeFailureCompletesTheExplicitCallRead() async throws {
    let (p, s) = make()
    s.failure = FeeFixtureFailure.offline
    let value = try await p.getFee(for: SubstrateCallFactory().reserveReferralBalance(balance: 1))
    XCTAssertEqual(value, 0)
  }
  func testMalformedFeeCompletesTheExplicitCallRead() async throws {
    let (p, s) = make()
    s.rawFee = "invalid"
    let value = try await p.getFee(for: SubstrateCallFactory().reserveReferralBalance(balance: 1))
    XCTAssertEqual(value, 0)
  }
  func testUnavailableServiceCompletesAnExplicitCallRead() async throws {
    let p = FeeProvider(account: nil)
    let value = try await p.getFee(for: SubstrateCallFactory().reserveReferralBalance(balance: 1))
    XCTAssertEqual(value, 0)
  }
  func testTransactionFeeCallbackRunsOnMainThreadExactlyOnce() async {
    let (p, s) = make()
    let done = expectation(description: "fee callback")
    done.assertForOverFulfill = true
    p.getFee(for: TransactionType.outgoing) { value in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(value, Decimal(string: "1.234567890123456789"))
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 1)
    XCTAssertEqual(s.estimateCount, 1)
  }
  func testBondFeeCallbackBuildsReserveBalanceAndRunsOnMain() async throws {
    try await assertReward(.bond, name: "reserve")
  }
  func testUnbondFeeCallbackBuildsUnreserveBalanceAndRunsOnMain() async throws {
    try await assertReward(.unbond, name: "unreserve")
  }
  private func assertReward(_ type: InputRewardAmountType, name: String) async throws {
    let (p, s) = make()
    let done = expectation(description: "reward fee")
    p.getFee(for: type) { value in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(value, Decimal(string: "1.234567890123456789"))
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 1)
    let raw = try JSONEncoder().encode(s.builders[0].calls[0])
    XCTAssertTrue(String(data: raw, encoding: .utf8)!.contains(name))
    XCTAssertEqual(s.submitCount, 0)
  }
}

private enum FeeFixtureFailure: Error { case offline, unexpected }
private final class FeeFixtureCall: CancellableCall {
  var cancelled = false
  func cancel() { cancelled = true }
}
private final class FeeFixtureService: ExtrinsicServiceProtocol {
  var rawFee = "7"
  var failure: Error?
  var builders: [FeeFixtureBuilder] = []
  var estimateCount = 0
  var prepareCount = 0
  var submitCount = 0
  var preparedSubmitCount = 0
  var cancelAfterPrepare = false
  var prepared: PreparedExtrinsicSubmission?
  let call = FeeFixtureCall()
  private func record(_ closure: ExtrinsicBuilderClosure) throws {
    let builder = FeeFixtureBuilder()
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
    completion(.failure(FeeFixtureFailure.unexpected))
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
    completion(.failure(FeeFixtureFailure.unexpected), nil, nil)
  }
  func prepare(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    runningIn queue: DispatchQueue,
    completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void
  ) {
    XCTFail("Unexpected unqualified preparation")
    completion(.failure(FeeFixtureFailure.unexpected))
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
    completion(.failure(FeeFixtureFailure.unexpected))
  }
  func submitPrepared(
    _ prepared: PreparedExtrinsicSubmission, retainingTransportWitness: Bool,
    expectedRawFee: String,
    preTransportValidation: @escaping () throws -> Void, runningIn queue: DispatchQueue,
    completion: @escaping (Result<String, Error>) -> Void
  ) -> CancellableCall {
    preparedSubmitCount += 1
    XCTFail("Unexpected transport")
    completion(.failure(FeeFixtureFailure.unexpected))
    return call
  }
}
private final class FeeFixtureBuilder: SoraPassport.ExtrinsicBuilderProtocol {
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
    throw FeeFixtureFailure.unexpected
  }
  func signing(
    by signer: (Data) throws -> Data, of type: SoraPassport.CryptoType,
    using encoder: DynamicScaleEncoding,
    metadata: RuntimeMetadata
  ) throws -> Self {
    XCTFail("Unexpected signing")
    throw FeeFixtureFailure.unexpected
  }
  func buildExtrinsic(metadata: RuntimeMetadata) throws -> Extrinsic {
    XCTFail("Unexpected extrinsic build")
    throw FeeFixtureFailure.unexpected
  }
  func build(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws -> Data {
    throw FeeFixtureFailure.unexpected
  }
  func buildSignature(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws
    -> Data
  { throw FeeFixtureFailure.unexpected }
}
