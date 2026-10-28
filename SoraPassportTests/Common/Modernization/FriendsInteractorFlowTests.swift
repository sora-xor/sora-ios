import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFStorageQueryKitFixed
import SSFUtils
import sorawallet
import XCTest
@testable import SoraPassport

@MainActor
final class FriendsInteractorFlowTests: XCTestCase {
    private func settle(_ condition: @escaping () -> Bool = { false }) async {
        for _ in 0..<100 { if condition() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
    }
    private func ready(_ f: FriendsFlowFixture) async {
        f.interactor?.setup()
        await settle { !f.output.received.isEmpty || !f.output.errors.isEmpty }
    }
    private func actualFactory(engine: FriendsFlowEngine, address: String? = nil) throws -> ReferralsOperationFactory {
        let key = Data(repeating: 0x42, count: 32)
        let selected = AccountItem(address: try address ?? SS58AddressFactory().addressFromAccountId(data: key, type: ApplicationConfig.shared.addressType), cryptoType: .sr25519, networkType: 69, username: "Fixture", publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        return ReferralsOperationFactory(settings: InMemorySettingsManager(), keychain: InMemoryKeychain(), engine: engine,
                                         runtimeRegistry: FriendsFlowRuntime(), selectedAccount: selected)
    }
    private func read<T>(_ operation: BaseOperation<T>) async throws -> T {
        let done = expectation(description: "Referral read completed")
        operation.completionBlock = { done.fulfill() }
        OperationQueue().addOperation(operation)
        await fulfillment(of: [done], timeout: 2)
        return try operation.extractResultData(throwing: BaseOperationError.unexpectedDependentResult)
    }
    func testActualFactoryTreatsNullReferrerStorageAsNoReferrer() async throws {
        let engine = FriendsFlowEngine(); engine.readAnswer = Data("null".utf8)
        let factory = try actualFactory(engine: engine)
        let value = try await read(XCTUnwrap(factory.createReferrerOperation()))
        XCTAssertNil(value as Any?)
    }
    func testActualFactoryPreservesKnownReferrerBytes() async throws {
        let engine = FriendsFlowEngine(); let hex = "0x" + String(repeating: "43", count: 32)
        engine.readAnswer = try JSONEncoder().encode(hex)
        let value = try await read(XCTUnwrap(actualFactory(engine: engine).createReferrerOperation()))
        XCTAssertEqual(value, hex)
        XCTAssertEqual(engine.readMethods, [SoraPassport.RPCMethod.getStorage])
    }
    func testActualFactoryDecodesExactBalanceStorage() async throws {
        let engine = FriendsFlowEngine(); engine.readAnswer = try JSONEncoder().encode(FriendsFlowFixture.balanceHex(9))
        let value = try await read(XCTUnwrap(actualFactory(engine: engine).createReferrerBalancesOperation()))
        XCTAssertEqual(value.underlyingValue?.value, BigUInt(9) * BigUInt(10).power(18))
        XCTAssertEqual(engine.readMethods, [SoraPassport.RPCMethod.getStorage])
    }
    func testActualFactoryTreatsNullBalanceStorageAsAbsent() async throws {
        let engine = FriendsFlowEngine(); engine.readAnswer = Data("null".utf8)
        let value = try await read(XCTUnwrap(actualFactory(engine: engine).createReferrerBalancesOperation()))
        XCTAssertNil(value.underlyingValue)
    }
    func testActualFactoryRejectsMalformedBalanceScale() async throws {
        let engine = FriendsFlowEngine(); engine.readAnswer = Data("\"0x01\"".utf8)
        do { _ = try await read(XCTUnwrap(actualFactory(engine: engine).createReferrerBalancesOperation())); XCTFail("Malformed SCALE accepted") }
        catch { }
    }
    func testActualFactoryPreservesRPCFailure() async throws {
        let engine = FriendsFlowEngine(); engine.readFailure = FriendsFlowFailure.offline
        do { _ = try await read(XCTUnwrap(actualFactory(engine: engine).createReferrerOperation())); XCTFail("RPC error swallowed") }
        catch { XCTAssertTrue(error is FriendsFlowFailure) }
    }
    func testActualFactoryRejectsInvalidAccountBeforeCreatingReads() throws {
        let engine = FriendsFlowEngine(); let factory = try actualFactory(engine: engine, address: "invalid")
        XCTAssertNil(factory.createReferrerOperation()); XCTAssertNil(factory.createReferrerBalancesOperation())
        XCTAssertTrue(engine.readMethods.isEmpty)
    }
    func testActualFactoryUsesDistinctAccountBoundStorageKeys() async throws {
        let engine = FriendsFlowEngine(); engine.readAnswer = try JSONEncoder().encode(FriendsFlowFixture.balanceHex(1))
        let factory = try actualFactory(engine: engine)
        _ = try await read(XCTUnwrap(factory.createReferrerBalancesOperation()))
        engine.readAnswer = try JSONEncoder().encode("0x" + String(repeating: "43", count: 32))
        _ = try await read(XCTUnwrap(factory.createReferrerOperation()))
        XCTAssertEqual(engine.readParameters.count, 2)
        XCTAssertEqual(engine.readParameters.map(\.count), [1, 1])
        XCTAssertNotEqual(engine.readParameters[0], engine.readParameters[1])
        XCTAssertTrue(engine.readParameters.allSatisfy { $0.first?.hasSuffix(String(repeating: "42", count: 32)) == true })
    }
    func testSetupPublishesExactRewardsFeesBalanceAndReferrer() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        let r = try XCTUnwrap(f.output.received.first)
        XCTAssertEqual(r.rewards.map(\.amount), ["2500000000000000000"])
        XCTAssertEqual(r.setFee, 1); XCTAssertEqual(r.bondFee, 2); XCTAssertEqual(r.unbondFee, 3)
        XCTAssertEqual(r.balance, 5); XCTAssertEqual(r.referrer, f.referrer)
        XCTAssertTrue(f.output.threads.allSatisfy { $0 })
        XCTAssertEqual(f.engine.subscriptions.count, 3)
    }
    func testEmptyRewardResponseIsAValidLoadedState() async throws {
        let f = try FriendsFlowFixture(); f.rewards = []
        await ready(f); XCTAssertEqual(f.output.received.first?.rewards.count, 0)
    }
    func testNullReferrerReadPublishesAnUnreferredAccount() async throws {
        let f = try FriendsFlowFixture(); f.factory.referrer = .success(nil)
        await ready(f); XCTAssertEqual(f.output.received.first?.referrer, "")
        XCTAssertTrue(f.output.errors.isEmpty)
    }
    func testWrongLengthReferrerSubscriptionCannotPublishAnAddress() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        try await f.emit(index: 1, value: "0x01")
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(f.output.referrers.isEmpty)
    }
    func testAbsentBalanceStorageIsAnAuthoritativeZero() async throws {
        let f = try FriendsFlowFixture(); f.factory.balance = .success(JSONScaleDecodable(value: nil))
        await ready(f); XCTAssertEqual(f.output.received.first?.balance, 0)
    }
    func testMissingBalanceOperationFinishesWithAnError() async throws {
        let f = try FriendsFlowFixture(); f.factory.missingBalance = true
        await ready(f); XCTAssertEqual(f.output.errors.count, 1); XCTAssertTrue(f.output.received.isEmpty)
    }
    func testMissingReferrerOperationFinishesWithAnError() async throws {
        let f = try FriendsFlowFixture(); f.factory.missingReferrer = true
        await ready(f); XCTAssertEqual(f.output.errors.count, 1); XCTAssertTrue(f.output.received.isEmpty)
    }
    func testBalanceReadErrorIsNotAnInventedZeroBalance() async throws {
        let f = try FriendsFlowFixture(); f.factory.balance = .failure(FriendsFlowFailure.offline)
        await ready(f); XCTAssertEqual(f.output.errors.count, 1); XCTAssertTrue(f.output.received.isEmpty)
    }
    func testReferrerReadErrorIsNotAnUnreferredAccount() async throws {
        let f = try FriendsFlowFixture(); f.factory.referrer = .failure(FriendsFlowFailure.offline)
        await ready(f); XCTAssertEqual(f.output.errors.count, 1); XCTAssertTrue(f.output.received.isEmpty)
    }
    func testRewardsReadErrorFinishesLoading() async throws {
        let f = try FriendsFlowFixture(); f.rewardError = FriendsFlowFailure.offline
        await ready(f); XCTAssertEqual(f.output.errors.count, 1); XCTAssertTrue(f.output.received.isEmpty)
    }
    func testMalformedReferrerHexFinishesLoading() async throws {
        let f = try FriendsFlowFixture(); f.factory.referrer = .success("not-hex")
        await ready(f); XCTAssertEqual(f.output.errors.count, 1); XCTAssertTrue(f.output.received.isEmpty)
    }
    func testWrongLengthReferrerKeyFinishesLoading() async throws {
        let f = try FriendsFlowFixture(); f.factory.referrer = .success("0x01")
        await ready(f); XCTAssertEqual(f.output.errors.count, 1); XCTAssertTrue(f.output.received.isEmpty)
    }
    func testUnavailableFeeDoesNotPublishActionableReferralScreen() async throws {
        let f = try FriendsFlowFixture(); f.fees.referral = .nan
        await ready(f); XCTAssertEqual(f.output.errors.count, 1); XCTAssertTrue(f.output.received.isEmpty)
    }
    func testNegativeBondFeeIsRejected() async throws {
        let f = try FriendsFlowFixture(); f.fees.bond = -1
        await ready(f); XCTAssertEqual(f.output.errors.count, 1); XCTAssertTrue(f.output.received.isEmpty)
    }
    func testFailedSetupDoesNotSubscribe() async throws {
        let f = try FriendsFlowFixture(); f.factory.balance = .failure(FriendsFlowFailure.offline)
        await ready(f); XCTAssertTrue(f.engine.subscriptions.isEmpty)
    }
    func testRepeatedSetupReplacesExistingSubscriptions() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        let first = f.engine.subscriptions.map(\.id)
        f.interactor?.setup(); await settle { f.output.received.count == 2 }
        XCTAssertEqual(f.engine.cancelled.sorted(), first.sorted())
        XCTAssertEqual(f.engine.subscriptions.count - f.engine.cancelled.count, 3)
    }
    func testOverlappingSetupPublishesOnlyTheLatestSnapshot() async throws {
        let f = try FriendsFlowFixture(); f.fees.hold = true
        f.interactor?.setup()
        await settle { f.fees.completions.count == 3 }
        f.factory.balance = .success(JSONScaleDecodable(value: Balance(value: BigUInt(9) * BigUInt(10).power(18))))
        f.interactor?.setup()
        await settle { f.fees.completions.count == 6 }
        for completion in f.fees.completions.dropFirst(3) { completion() }
        await settle { !f.output.received.isEmpty }
        for completion in f.fees.completions.prefix(3) { completion() }
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(f.output.received.count, 1)
        XCTAssertEqual(f.output.received.first?.balance, 9)
        XCTAssertEqual(f.engine.subscriptions.count, 3)
    }
    func testLateFailureFromAnOlderSetupCannotReplaceTheLatestSuccess() async throws {
        let f = try FriendsFlowFixture(); f.fees.hold = true
        f.rewardError = FriendsFlowFailure.offline
        f.interactor?.setup()
        await settle { f.fees.completions.count == 3 }
        f.rewardError = nil
        f.interactor?.setup()
        await settle { f.fees.completions.count == 6 }
        for completion in f.fees.completions.dropFirst(3) { completion() }
        await settle { !f.output.received.isEmpty }
        for completion in f.fees.completions.prefix(3) { completion() }
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(f.output.received.count, 1)
        XCTAssertTrue(f.output.errors.isEmpty)
    }
    func testDeinitCancelsEverySubscription() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        let ids = f.engine.subscriptions.map(\.id)
        weak var weakInteractor = f.interactor
        f.interactor = nil
        XCTAssertNil(weakInteractor)
        XCTAssertEqual(f.engine.cancelled.sorted(), ids.sorted())
    }
    func testBalanceSubscriptionPublishesExactAmountOnMainQueue() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        try await f.emit(index: 0, value: FriendsFlowFixture.balanceHex(7))
        await settle { !f.output.balances.isEmpty }
        XCTAssertEqual(f.output.balances, [7])
        XCTAssertTrue(f.output.threads.allSatisfy { $0 })
    }
    func testBalanceSubscriptionSuppressesRepeatedValues() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        try await f.emit(index: 0, value: FriendsFlowFixture.balanceHex(7))
        try await f.emit(index: 0, value: FriendsFlowFixture.balanceHex(7))
        await settle { !f.output.balances.isEmpty }
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(f.output.balances, [7])
    }
    func testBalanceSubscriptionSuppressesItsInitialSnapshot() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        try await f.emit(index: 0, value: FriendsFlowFixture.balanceHex(5))
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(f.output.balances.isEmpty)
    }
    func testMalformedBalanceUpdateCannotEraseLastKnownBalance() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        try await f.emit(index: 0, value: "0x01")
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(f.output.balances.isEmpty)
    }
    func testTrailingBytesInBalanceUpdateAreRejected() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        try await f.emit(index: 0, value: FriendsFlowFixture.balanceHex(7) + "00")
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(f.output.balances.isEmpty)
    }
    func testUnrelatedStorageChangeCannotReplaceBalance() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        try await f.emit(index: 0, value: FriendsFlowFixture.balanceHex(7), key: "unrelated")
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(f.output.balances.isEmpty)
    }
    func testDeletedBalanceStoragePublishesZeroOnce() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        try await f.emit(index: 0, value: nil); try await f.emit(index: 0, value: nil)
        await settle { !f.output.balances.isEmpty }
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(f.output.balances, [0])
    }
    func testReferrerSubscriptionPublishesAndDeduplicates() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        let key = Data(repeating: 0x43, count: 32)
        let hex = "0x" + key.map { String(format: "%02x", $0) }.joined()
        let address = try SS58AddressFactory().addressFromAccountId(data: key, type: ApplicationConfig.shared.addressType)
        try await f.emit(index: 1, value: hex); try await f.emit(index: 1, value: hex)
        await settle { !f.output.referrers.isEmpty }
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(f.output.referrers, [address])
    }
    func testDeletedReferrerStorageClearsTheReferrer() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        try await f.emit(index: 1, value: nil)
        await settle { !f.output.referrers.isEmpty }
        XCTAssertEqual(f.output.referrers, [""])
    }
    func testMalformedReferrerUpdateDoesNotEraseReferrer() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        try await f.emit(index: 1, value: "invalid")
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(f.output.referrers.isEmpty)
    }
    func testUnrelatedStorageChangeCannotReplaceReferrer() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        try await f.emit(index: 1, value: "0x" + String(repeating: "43", count: 32), key: "unrelated")
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(f.output.referrers.isEmpty)
    }
    func testOldSubscriptionCannotUpdateARefreshedScreen() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        f.interactor?.setup(); await settle { f.output.received.count == 2 }
        try await f.emit(index: 0, value: FriendsFlowFixture.balanceHex(9))
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(f.output.balances.isEmpty)
    }
    func testRewardSubscriptionRefreshesExactNewRewards() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        f.rewards = [ReferrerReward(referral: "new", amount: "3")]
        try await f.emit(index: 2, value: FriendsFlowFixture.balanceHex(7))
        await settle { !f.output.rewards.isEmpty }
        XCTAssertEqual(f.output.rewards.first?.first?.referral, "new")
        XCTAssertEqual(f.output.rewards.first?.first?.amount, "3")
        XCTAssertTrue(f.output.threads.allSatisfy { $0 })
    }
    func testFailedRewardRefreshCannotRepublishOldRewardsAsFresh() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        f.rewardError = FriendsFlowFailure.offline
        try await f.emit(index: 2, value: FriendsFlowFixture.balanceHex(7))
        await settle { !f.output.errors.isEmpty || !f.output.rewards.isEmpty }
        XCTAssertTrue(f.output.rewards.isEmpty)
        XCTAssertEqual(f.output.errors.count, 1)
    }
    func testUnrelatedStorageChangeDoesNotReloadRewards() async throws {
        let f = try FriendsFlowFixture(); await ready(f)
        let before = f.rewardRequests
        try await f.emit(index: 2, value: FriendsFlowFixture.balanceHex(7), key: "unrelated")
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(f.rewardRequests, before)
    }
}
private enum FriendsFlowFailure: Swift.Error { case offline }
private final class FriendsFlowFixture {
    var interactor: FriendsInteractor?
    let engine = FriendsFlowEngine(), output = FriendsFlowOutput(), fees = FriendsFlowFees()
    let factory: FriendsFlowFactory
    let referrer: String
    var rewards = [ReferrerReward(referral: "fixture", amount: "2500000000000000000")]
    var rewardError: Swift.Error?
    var rewardRequests = 0
    init() throws {
        factory = FriendsFlowFactory(engine: engine)
        referrer = try SS58AddressFactory().addressFromAccountId(data: Data(repeating: 0x42, count: 32), type: ApplicationConfig.shared.addressType)
        interactor = FriendsInteractor(engine: engine, address: referrer, config: ApplicationConfig.shared,
            operationManager: OperationManager(), keychain: Keychain(), operationFactory: factory, feeProvider: fees,
            rewardsOperation: { [unowned self] _ in
                self.rewardRequests += 1
                let op = BaseOperation<ReferrerRewardsInfo>()
                if let error = self.rewardError { op.result = .failure(error) }
                else { op.result = .success(ReferrerRewardsInfo(rewards: self.rewards)) }
                return op
            })
        interactor?.presenter = output
    }
    static func balanceHex(_ whole: UInt64) -> String {
        var data = Array((BigUInt(whole) * BigUInt(10).power(18)).serialize().reversed())
        data += Array(repeating: 0, count: 16 - data.count)
        return "0x" + data.map { String(format: "%02x", $0) }.joined()
    }
    func emit(index: Int, value: String?, key: String? = nil) async throws {
        guard engine.subscriptions.indices.contains(index) else { XCTFail("Missing subscription \(index)"); return }
        let sub = engine.subscriptions[index]
        let object: [String: Any] = ["jsonrpc": "2.0", "method": "state_storage", "params": ["subscription": String(sub.id), "result": ["block": "0x01", "changes": [[key ?? sub.key, value as Any? ?? NSNull()]]]]]
        let data = try JSONSerialization.data(withJSONObject: object)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
            DispatchQueue.global().async {
                do { try sub.deliver(data); continuation.resume() }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}
private final class FriendsFlowFactory: ReferralsOperationFactoryProtocol {
    let engine: FriendsFlowEngine
    var missingBalance = false, missingReferrer = false
    var balance: Result<JSONScaleDecodable<Balance>, Swift.Error> = .success(JSONScaleDecodable(value: Balance(value: BigUInt(5) * BigUInt(10).power(18))))
    var referrer: Result<String?, Swift.Error> = .success("0x" + String(repeating: "42", count: 32))
    init(engine: FriendsFlowEngine) { self.engine = engine }
    func createReferrerBalancesOperation() -> JSONRPCListOperation<JSONScaleDecodable<Balance>>? {
        guard !missingBalance else { return nil }
        let op = JSONRPCListOperation<JSONScaleDecodable<Balance>>(engine: engine, method: "fixture-balance")
        op.result = balance; return op
    }
    func createReferrerOperation() -> JSONRPCListOperation<String?>? {
        guard !missingReferrer else { return nil }
        let op = JSONRPCListOperation<String?>(engine: engine, method: "fixture-referrer")
        op.result = referrer; return op
    }
    func createExtrinsicSetReferrerOperation(with address: String) -> BaseOperation<String> { XCTFail("Unexpected signing"); return BaseOperation() }
    func createExtrinsicReserveReferralBalanceOperation(with balance: BigUInt) -> BaseOperation<String> { XCTFail("Unexpected signing"); return BaseOperation() }
    func createExtrinsicUnreserveReferralBalanceOperation(with balance: BigUInt) -> BaseOperation<String> { XCTFail("Unexpected signing"); return BaseOperation() }
}
private final class FriendsFlowFees: FeeProviderProtocol {
    var referral: Decimal = 1, bond: Decimal = 2, unbond: Decimal = 3
    var hold = false
    var completions = [() -> Void]()
    private func deliver(_ value: Decimal, _ completion: @escaping (Decimal) -> Void) {
        if hold { completions.append { completion(value) } } else { completion(value) }
    }
    func getFee(for type: TransactionType, completion: @escaping (Decimal) -> Void) { deliver(referral, completion) }
    func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void) { deliver(type == .bond ? bond : unbond, completion) }
    func getFee(for call: any RuntimeCallable) async -> Decimal { XCTFail("Unexpected fee request"); return .nan }
    func getFee(for type: TransactionType) async -> Decimal { referral }
}
private final class FriendsFlowOutput: FriendsInteractorOutputProtocol {
    struct Received { let rewards: [ReferrerReward]; let setFee, bondFee, unbondFee, balance: Decimal; let referrer: String }
    var received = [Received](), balances = [Decimal](), referrers = [String](), rewards = [[ReferrerReward]](), errors = [Swift.Error](), threads = [Bool]()
    func didFailLoading(error: Swift.Error) { threads.append(Thread.isMainThread); errors.append(error) }
    func didReceive(rewards: [ReferrerReward], setReferrerFee: Decimal, bondFee: Decimal, unbondFee: Decimal, referralBalance: Decimal, referrer: String) {
        threads.append(Thread.isMainThread); received.append(.init(rewards: rewards, setFee: setReferrerFee, bondFee: bondFee, unbondFee: unbondFee, balance: referralBalance, referrer: referrer))
    }
    func updateReferrer(address: String) { threads.append(Thread.isMainThread); referrers.append(address) }
    func updateReferral(balance: Decimal) { threads.append(Thread.isMainThread); balances.append(balance) }
    func updateReferral(rewards: [ReferrerReward]) { threads.append(Thread.isMainThread); self.rewards.append(rewards) }
}
private final class FriendsFlowEngine: JSONRPCEngine {
    struct Subscription { let id: UInt16; let key: String; let deliver: (Data) throws -> Void }
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }
    var subscriptions = [Subscription](), cancelled = [UInt16]()
    var readAnswer: Data?
    var readFailure: Swift.Error?
    var readMethods = [String](), readParameters = [[String]]()
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Swift.Error>) -> Void)?) throws -> UInt16 {
        readMethods.append(method)
        readParameters.append(try JSONDecoder().decode([String].self, from: JSONEncoder().encode(params)))
        if let readFailure { closure?(.failure(readFailure)); return 1 }
        guard let readAnswer else { XCTFail("Unexpected unmocked read \(method)"); throw FriendsFlowFailure.offline }
        closure?(.success(try JSONDecoder().decode(T.self, from: readAnswer)))
        return 1
    }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Swift.Error, Bool) -> Void) throws -> UInt16 {
        let parameters = try JSONDecoder().decode([[String]].self, from: JSONEncoder().encode(params))
        let id = UInt16(subscriptions.count + 1)
        subscriptions.append(.init(id: id, key: parameters[0][0], deliver: { data in updateClosure(try JSONDecoder().decode(T.self, from: data)) }))
        return id
    }
    func cancelForIdentifier(_ identifier: UInt16) { cancelled.append(identifier) }
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_ subscription: JSONRPCSubscribing) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ identifier: UInt16) throws {}
}

private final class FriendsFlowRuntime: RuntimeProviderProtocol {
    let chainId = PIIndexerClient.soraMainnetGenesis
    var snapshot: RuntimeSnapshot? { nil }
    func setup() {}
    func setupHot() {}
    func replaceTypesUsage(_ usage: SoraPassport.ChainModel.TypesUsage) {}
    func cleanup() {}
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        XCTFail("Referral reads must not sign or use runtime metadata")
        return ClosureOperation { throw FriendsFlowFailure.offline }
    }
}
