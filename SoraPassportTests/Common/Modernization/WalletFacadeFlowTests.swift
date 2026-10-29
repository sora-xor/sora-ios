// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import sorawallet
import IrohaCrypto
import RobinHood
import SoraFoundation
import SSFUtils
import XCTest
@testable import SoraPassport

/// Exercises facade operations with public account fixtures and in-memory RPC/storage boundaries.
@MainActor
final class WalletFacadeFlowTests: XCTestCase {
    private func equal<T: Equatable>(_ value: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) { XCTAssertEqual(value, expected, file: file, line: line) }
    private func truth(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) { XCTAssertTrue(value, file: file, line: line) }
    private func falsehood(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) { XCTAssertFalse(value, file: file, line: line) }
    private let queue = OperationQueue()
    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) async throws -> T {
        let done = expectation(description: "facade operation completes")
        wrapper.targetOperation.completionBlock = { done.fulfill() }
        wrapper.allOperations.forEach { queue.addOperation($0) }
        await fulfillment(of: [done], timeout: 3)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }
    private func rows(_ f: FacadeFixture) async throws -> [TransactionHistoryItem] {
        try await run(.init(targetOperation: f.transactions.fetchAllOperation(with: RepositoryFetchOptions())))
    }
    private func seed(_ f: FacadeFixture, _ accounts: [AccountItem]) async throws {
        try await run(.init(targetOperation: f.accounts.replaceOperation { accounts }))
    }
    private func expectFailure<T>(_ block: () async throws -> T, file: StaticString = #filePath, line: UInt = #line) async {
        do { _ = try await block(); XCTFail("Expected failed read", file: file, line: line) } catch {}
    }
    func testContactsMergeLocalAccountsAndRemotePeers() async throws {
        let f = try FacadeFixture(); let account = try f.account(1, name: "Alice")
        try await seed(f, [account]); f.contacts.items = [try f.contact(2, name: "Bob")]
        let result = try await run(f.facade.contactsOperation())
        equal(result?.map(\.lastName), ["Alice", "Bob"])
        equal(result?.map(\.firstName), [account.address, try f.contact(2).peerAddress])
    }
    func testLocalAccountWinsOverDuplicateContact() async throws {
        let f = try FacadeFixture(); try await seed(f, [f.account(1, name: "Local")])
        f.contacts.items = [try f.contact(1, name: "Old remote name")]
        equal(try await run(f.facade.contactsOperation())?.map(\.lastName), ["Local"])
    }
    func testContactSearchMatchesNameCaseInsensitively() async throws {
        let f = try FacadeFixture(); f.contacts.items = [try f.contact(1, name: "ALIce"), try f.contact(2, name: "Bob")]
        equal(try await run(f.facade.searchOperation("ali"))?.map(\.lastName), ["ALIce"])
    }
    func testContactSearchMatchesAddressAndEmptyQuery() async throws {
        let f = try FacadeFixture(); let contact = try f.contact(1)
        f.contacts.items = [contact]
        equal(try await run(f.facade.searchOperation(contact.peerAddress))?.count, 1)
        equal(try await run(f.facade.searchOperation(""))?.count, 1)
        equal(try await run(f.facade.searchOperation("no match"))?.count, 0)
    }
    func testContactReadFailurePropagatesThroughSearch() async throws {
        let f = try FacadeFixture(); f.contacts.failure = FacadeFailure.offline
        await expectFailure { try await run(f.facade.searchOperation("Alice")) }
    }
    func testMalformedContactAddressFailsInsteadOfPublishingWrongRecipient() async throws {
        let f = try FacadeFixture(); f.contacts.items = [.init(peerAddress: "bad", peerName: "Alice", targetAddress: f.address, updatedAt: 0)]
        await expectFailure { try await run(f.facade.contactsOperation()) }
    }
    func testEmptyContactsAreAnAuthoritativeEmptyResult() async throws {
        let f = try FacadeFixture()
        equal(try await run(f.facade.contactsOperation())?.count, 0)
    }
    func testUnmappedPriceDoesNotStartAnExternalRequest() async throws {
        let f = try FacadeFixture()
        let result = try await run(f.facade.fetchPriceOperation(.xor))
        XCTAssertNil(result); truth(f.prices.requests.isEmpty)
    }
    func testPriceUsesTokenIdAndConvertsPercentageToFraction() async throws {
        let f = try FacadeFixture(); f.prices.values = [.init(price: "2.125", usdDayChange: -12.5)]
        let result = try await run(f.facade.fetchPriceOperation(.xor, tokenId: "sora"))
        equal(result?.lastValue, Decimal(string: "2.125")); equal(result?.change, Decimal(string: "-0.125"))
        equal(f.prices.requests, [["sora"]])
    }
    func testPriceFailureDoesNotBecomeAZeroPrice() async throws {
        let f = try FacadeFixture(); f.prices.failure = FacadeFailure.offline
        await expectFailure { try await run(f.facade.fetchPriceOperation(.xor, tokenId: "sora")) }
    }
    func testMissingPriceDoesNotBecomeAZeroPrice() async throws {
        let f = try FacadeFixture(); f.prices.values = []
        await expectFailure { try await run(f.facade.fetchPriceOperation(.xor, tokenId: "sora")) }
    }
    func testMalformedPriceDoesNotPartiallyParse() async throws {
        let f = try FacadeFixture(); f.prices.values = [.init(price: "2trailing", usdDayChange: 0)]
        await expectFailure { try await run(f.facade.fetchPriceOperation(.xor, tokenId: "sora")) }
    }
    func testNegativePriceIsRejected() async throws {
        let f = try FacadeFixture(); f.prices.values = [.init(price: "-1", usdDayChange: 0)]
        await expectFailure { try await run(f.facade.fetchPriceOperation(.xor, tokenId: "sora")) }
    }
    func testLegacyOrdinaryTransferDoesNotReachNodeOrWriteHistory() async throws {
        let f = try FacadeFixture(); var called = false
        f.node.transferClosure = { _ in called = true; return .init(targetOperation: ClosureOperation { Data() }) }
        await expectFailure { try await run(f.facade.transferOperation(f.transfer())) }
        falsehood(called); truth(try await rows(f).isEmpty)
    }
    func testPreparedTransferPersistsBeforeTransportAndReturnsExactHash() async throws {
        let f = try FacadeFixture(); let prepared = f.prepared()
        var validationCalls = 0
        f.node.submitPreparedTransferClosure = { [self] _, _, validate in
            let pending = try await rows(f); equal(pending.count, 1)
            equal(pending.first?.txHash, prepared.transactionHash)
            try validate(); return Data(repeating: 8, count: 32)
        }
        let hash = try await f.facade.submitPreparedTransfer(prepared, info: f.transfer(), preTransportValidation: { validationCalls += 1 })
        equal(hash, Data(repeating: 8, count: 32)); equal(validationCalls, 1)
        equal(try await rows(f).count, 1)
    }
    func testDefinitivePreTransportFailureRemovesPendingHistory() async throws {
        let f = try FacadeFixture(); f.node.submitPreparedTransferClosure = { _, _, _ in throw PreparedExtrinsicTransportError.failedBeforeTransport(FacadeFailure.offline) }
        await expectFailure { try await f.facade.submitPreparedTransfer(f.prepared(), info: f.transfer(), preTransportValidation: {}) }
        truth(try await rows(f).isEmpty)
    }
    func testAmbiguousTransportFailureRetainsPendingHistory() async throws {
        let f = try FacadeFixture(); f.node.submitPreparedTransferClosure = { _, _, _ in throw PreparedExtrinsicTransportError.submissionUnknown(FacadeFailure.offline) }
        await expectFailure { try await f.facade.submitPreparedTransfer(f.prepared(), info: f.transfer(), preTransportValidation: {}) }
        equal(try await rows(f).count, 1)
    }
    func testUnclassifiedTransportFailureIsWrappedWithExactLocalHash() async throws {
        let f = try FacadeFixture(); let prepared = f.prepared()
        f.node.submitPreparedTransferClosure = { _, _, _ in throw FacadeFailure.offline }
        do { _ = try await f.facade.submitPreparedTransfer(prepared, info: f.transfer(), preTransportValidation: {}); XCTFail("Expected ambiguous failure") }
        catch let error as PreparedExtrinsicTransportError {
            guard case let .submissionUnknown(underlying) = error else { return XCTFail("Unexpected definitive failure") }
            equal(try (underlying as? Sora2SubmissionUnknownContext).map { try Data(hexStringSSF: $0.transactionHash) }, try Data(hexStringSSF: prepared.transactionHash))
        }
        equal(try await rows(f).count, 1)
    }
    func testInvalidPreparedHashIsDiscardedBeforeNodeOrHistory() async throws {
        let f = try FacadeFixture(); let prepared = f.prepared(hash: "invalid")
        var reached = false; f.node.submitPreparedTransferClosure = { _, _, _ in reached = true; return Data() }
        await expectFailure { try await f.facade.submitPreparedTransfer(prepared, info: f.transfer(), preTransportValidation: {}) }
        falsehood(reached); truth(try await rows(f).isEmpty)
        XCTAssertThrowsError(try prepared.preparedExtrinsic.consumeForTransport())
    }
    func testFeeEstimationDelegatesExactTransferAndError() async throws {
        let f = try FacadeFixture(); let info = f.transfer()
        f.node.transferFeeClosure = { value in self.equal(value.destination, info.destination); return Decimal(string: "0.003")! }
        equal(try await f.facade.estimateTransferFee(for: info), Decimal(string: "0.003"))
        f.node.transferFeeClosure = { _ in throw FacadeFailure.offline }
        await expectFailure { try await f.facade.estimateTransferFee(for: info) }
    }
    func testLiquidityFeeDelegatesExactTransfer() async throws {
        let f = try FacadeFixture(); f.node.liquidityFeeClosure = { value in self.equal(value.asset, WalletAssetId.val.rawValue); return 2 }
        equal(try await f.facade.estimateLiquidityFee(for: f.transfer()), 2)
    }
    func testTransferPreparationForwardsPreSigningValidation() async throws {
        let f = try FacadeFixture(); let prepared = f.prepared(); var checked = 0
        f.node.prepareTransferClosure = { _, validate in try validate(); return prepared }
        let result = try await f.facade.prepareTransferSubmission(for: f.transfer(), preSigningValidation: { checked += 1 })
        truth(result === prepared); equal(checked, 1)
    }
    func testTransferPreparationPreservesValidationFailure() async throws {
        let f = try FacadeFixture(); f.node.prepareTransferClosure = { _, validate in try validate(); return f.prepared() }
        await expectFailure { try await f.facade.prepareTransferSubmission(for: f.transfer(), preSigningValidation: { throw FacadeFailure.offline }) }
    }
    func testLiquidityPreparationForwardsPreSigningValidation() async throws {
        let f = try FacadeFixture(); let prepared = try f.preparedLiquidity(); var checked = 0
        f.node.prepareLiquidityClosure = { _, validate in try validate(); return prepared }
        let result = try await f.facade.prepareLiquiditySubmission(for: f.liquidity(), preSigningValidation: { checked += 1 })
        truth(result === prepared); equal(checked, 1)
    }
    func testPreparedLiquidityPersistsExactCallAndFeeBeforeTransport() async throws {
        let f = try FacadeFixture(); let prepared = try f.preparedLiquidity(); var checked = 0
        f.node.submitPreparedLiquidityClosure = { [self] _, _, validate in
            let allRows = try await rows(f)
            let pending = try XCTUnwrap(allRows.first)
            equal(pending.fee, "17"); equal(pending.callPath.moduleName, CallCodingPath.depositLiquidity.moduleName); equal(pending.callPath.callName, CallCodingPath.depositLiquidity.callName)
            let call = try JSONDecoder.scaleCompatible().decode(RuntimeCall<JSON>.self, from: pending.call)
            equal(call.args.dictValue?["amount"], .stringValue("123"))
            try validate(); return Data(repeating: 7, count: 32)
        }
        let result = try await f.facade.submitPreparedLiquidity(prepared, info: f.liquidity(), preTransportValidation: { checked += 1 })
        equal(result, Data(repeating: 7, count: 32)); equal(checked, 1); equal(try await rows(f).count, 1)
    }
    func testDefinitiveLiquidityFailureRemovesPendingHistory() async throws {
        let f = try FacadeFixture(); f.node.submitPreparedLiquidityClosure = { _, _, _ in throw PreparedExtrinsicTransportError.failedBeforeTransport(FacadeFailure.offline) }
        await expectFailure { try await f.facade.submitPreparedLiquidity(f.preparedLiquidity(), info: f.liquidity(), preTransportValidation: {}) }
        truth(try await rows(f).isEmpty)
    }
    func testAmbiguousLiquidityFailureKeepsPendingHistory() async throws {
        let f = try FacadeFixture(); f.node.submitPreparedLiquidityClosure = { _, _, _ in throw PreparedExtrinsicTransportError.submissionUnknown(FacadeFailure.offline) }
        await expectFailure { try await f.facade.submitPreparedLiquidity(f.preparedLiquidity(), info: f.liquidity(), preTransportValidation: {}) }
        equal(try await rows(f).count, 1)
    }
    func testUnknownLiquidityFailureRetainsExactLocalHash() async throws {
        let f = try FacadeFixture(); let prepared = try f.preparedLiquidity()
        f.node.submitPreparedLiquidityClosure = { _, _, _ in throw FacadeFailure.offline }
        do { _ = try await f.facade.submitPreparedLiquidity(prepared, info: f.liquidity(), preTransportValidation: {}); XCTFail("Expected failure") }
        catch let error as PreparedExtrinsicTransportError {
            guard case let .submissionUnknown(underlying) = error else { return XCTFail("Expected unknown submission") }
            equal(try (underlying as? Sora2SubmissionUnknownContext).map { try Data(hexStringSSF: $0.transactionHash) }, try Data(hexStringSSF: prepared.transactionHash))
        }
        equal(try await rows(f).count, 1)
    }
    func testLiquidityWithoutExactCallIsDiscardedBeforeNode() async throws {
        let f = try FacadeFixture(); let prepared = try f.preparedLiquidity(includeCall: false); var reached = false
        f.node.submitPreparedLiquidityClosure = { _, _, _ in reached = true; return Data() }
        await expectFailure { try await f.facade.submitPreparedLiquidity(prepared, info: f.liquidity(), preTransportValidation: {}) }
        falsehood(reached); truth(try await rows(f).isEmpty)
        XCTAssertThrowsError(try prepared.preparedExtrinsic.consumeForTransport())
    }
    func testLiquidityRejectsMismatchedCallBeforeTransport() async throws {
        let f = try FacadeFixture(); let prepared = try f.preparedLiquidity(callName: "withdraw_liquidity"); var reached = false
        f.node.submitPreparedLiquidityClosure = { _, _, _ in reached = true; return Data() }
        await expectFailure { try await f.facade.submitPreparedLiquidity(prepared, info: f.liquidity(), preTransportValidation: {}) }
        falsehood(reached); truth(try await rows(f).isEmpty)
    }
    func testPoolDetailsUsesProportionalReservesAndRealStorageKeys() async throws {
        let f = try FacadeFixture(); try f.pool()
        let result = try await f.facade.getPoolDetails(baseAsset: f.xor, targetAsset: f.val)
        equal(result.yourPoolShare, 25); equal(result.baseAssetPooledByAccount, 50)
        equal(result.targetAssetPooledByAccount, 100); equal(result.accountPoolBalance, 5)
        equal(result.totalIssuances, 20); truth(result.farms.isEmpty)
        equal(f.farms.reads.count, 1)
    }
    func testPoolDetailsUsesEachAssetPrecision() async throws {
        let f = try FacadeFixture(); f.assets.items[1].precision = 6
        try f.pool(targetRaw: 400_000_000)
        let result = try await f.facade.getPoolDetails(baseAsset: f.xor, targetAsset: f.val)
        equal(result.targetAssetPooledTotal, 400); equal(result.targetAssetPooledByAccount, 100)
    }
    func testZeroIssuanceProducesZeroSharesWithoutNaN() async throws {
        let f = try FacadeFixture(); try f.pool(issuance: 0)
        let result = try await f.facade.getPoolDetails(baseAsset: f.xor, targetAsset: f.val)
        equal(result.yourPoolShare, 0); equal(result.baseAssetPooledByAccount, 0)
        equal(result.targetAssetPooledByAccount, 0)
    }
    func testPoolBalanceReadFailureIsNotShownAsZeroHolding() async throws {
        let f = try FacadeFixture(); try f.pool(); f.engine.failures.insert(try f.providerKey())
        await expectFailure { try await f.facade.getPoolDetails(baseAsset: f.xor, targetAsset: f.val) }
    }
    func testPoolFarmingFailurePropagates() async throws {
        let f = try FacadeFixture(); try f.pool(); f.farms.failure = FacadeFailure.offline
        await expectFailure { try await f.facade.getPoolDetails(baseAsset: f.xor, targetAsset: f.val) }
    }
    func testPoolReservesFailurePropagates() async throws {
        let f = try FacadeFixture(); try f.pool(); f.engine.failures.insert(try f.reservesKey())
        await expectFailure { try await f.facade.getPoolDetails(baseAsset: f.xor, targetAsset: f.val) }
    }
    func testPoolIssuanceFailurePropagates() async throws {
        let f = try FacadeFixture(); try f.pool(); f.engine.failures.insert(try f.issuanceKey())
        await expectFailure { try await f.facade.getPoolDetails(baseAsset: f.xor, targetAsset: f.val) }
    }
    func testMissingPoolPropertiesCannotQueryEmptyStorageKey() async throws {
        let f = try FacadeFixture(); try f.pool(); f.engine.values[try f.propertiesKey()] = nil
        await expectFailure { try await f.facade.getPoolDetails(baseAsset: f.xor, targetAsset: f.val) }
        falsehood(f.engine.queries.contains([]))
    }
    func testAccountPoolListReadFailurePropagatesInsteadOfEmptyPortfolio() async throws {
        let f = try FacadeFixture(); f.engine.failAll = true
        await expectFailure { try await run(f.facade.getAccountPoolsDetails()) }
    }
    func testEmptyAccountPoolListReturnsEmptyPortfolio() async throws {
        let f = try FacadeFixture()
        truth(try await run(f.facade.getAccountPoolsDetails()).isEmpty)
    }
    func testAccountPoolListLoadsEveryPairAndSortsByBase() async throws {
        let f = try FacadeFixture(); try f.pool()
        let key = try StorageKeyFactory().accountPoolsKeyForId(f.publicKey, baseAssetId: Data(hexStringSSF: f.xor)).toHex(includePrefix: true)
        f.engine.values[key] = "0x04" + String(f.val.dropFirst(2))
        let result = try await run(f.facade.getAccountPoolsDetails())
        equal(result.map(\.targetAsset), [f.val]); equal(result.map(\.baseAsset), [f.xor])
    }
    private func historyData(_ id: String, asset: String = WalletAssetId.xor.rawValue) -> AssetTransactionData {
        AssetTransactionData(transactionId: id, status: .commited, assetId: asset, peerId: "peer", peerFirstName: nil, peerLastName: nil, peerName: nil, details: "", amount: AmountDecimal(value: 1), fees: [], timestamp: 100, type: TransactionType.incoming.rawValue, reason: nil, context: nil)
    }
    private func completed<T>(_ value: T) -> BaseOperation<T> { let operation = BaseOperation<T>(); operation.result = .success(value); return operation }
    private func historyRemote(_ items: [WalletRemoteHistoryItemProtocol], cursor: Int? = 2, complete: Bool = false) -> BaseOperation<WalletRemoteHistoryData> {
        completed(WalletRemoteHistoryData(historyItems: items, context: TransactionHistoryContext(cursor: cursor, isComplete: complete)))
    }
    func testCompleteHistoryPageAvoidsSchedulingAnyReadOrMutation() async throws {
        let f = try FacadeFixture()
        let wrapper = f.facade.fetchTransactionHistoryOperation(WalletHistoryRequest(), pagination: Pagination(count: 10, context: [TransactionHistoryContext.isComplete: "true"]))
        XCTAssertEqual(wrapper.allOperations.count, 1)
        let page = try XCTUnwrap(try XCTUnwrap(wrapper.targetOperation.result).get())
        XCTAssertTrue(page.transactions.isEmpty); XCTAssertNil(page.context)
        truth(try await rows(f).isEmpty)
    }
    func testFirstHistoryPageAddsLocalAndPendingReadsBeforeMapping() throws {
        let f = try FacadeFixture()
        let first = f.facade.fetchTransactionHistoryOperation(WalletHistoryRequest(), pagination: Pagination(count: 10))
        let continuation = f.facade.fetchTransactionHistoryOperation(WalletHistoryRequest(), pagination: Pagination(count: 10, context: [TransactionHistoryContext.cursor: "2"]))
        XCTAssertEqual(first.allOperations.count, continuation.allOperations.count + 3)
        XCTAssertEqual(first.targetOperation.dependencies.count, first.allOperations.count - 1)
        XCTAssertEqual(continuation.targetOperation.dependencies.count, continuation.allOperations.count - 1)
        XCTAssertTrue(first.allOperations.allSatisfy { !$0.isExecuting && !$0.isFinished })
    }
    func testHistoryMergeConvertsRemoteRowsAndDiscardsUnprojectableRows() async throws {
        let f = try FacadeFixture(), expected = historyData("remote")
        let remote = historyRemote([FacadeRemoteHistory(id: "remote", transaction: expected), FacadeRemoteHistory(id: "unprojectable", transaction: nil)])
        let operation = f.facade.createHistoryMergeOperation(dependingOn: remote, localOperation: nil, pendingOperation: nil, feeAsset: f.facade.accountSettings.assets[0], address: f.address)
        let result = try await run(CompoundOperationWrapper(targetOperation: operation))
        equal(result.historyItems, [expected]); truth(result.identifiersToRemove.isEmpty)
    }
    func testHistoryMergeWithoutSourcesProducesAnEmptyPage() async throws {
        let f = try FacadeFixture()
        let operation = f.facade.createHistoryMergeOperation(dependingOn: nil, localOperation: nil, pendingOperation: nil, feeAsset: f.facade.accountSettings.assets[0], address: f.address)
        let result = try await run(CompoundOperationWrapper(targetOperation: operation))
        truth(result.historyItems.isEmpty); truth(result.identifiersToRemove.isEmpty)
    }
    func testHistoryMergeExcludesLocalRowsBelongingToOtherAccounts() async throws {
        let f = try FacadeFixture()
        let local = TransactionHistoryItem(sender: "other", receiver: "also-other", status: .pending, txHash: "0x1234", timestamp: 100, fee: "0", blockNumber: 1, txIndex: 0, callPath: CallCodingPath(moduleName: "System", callName: "remark"), call: Data())
        let operation = f.facade.createHistoryMergeOperation(dependingOn: historyRemote([]), localOperation: completed([local]), pendingOperation: completed([]), feeAsset: f.facade.accountSettings.assets[0], address: f.address)
        let result = try await run(CompoundOperationWrapper(targetOperation: operation)); truth(result.historyItems.isEmpty)
    }
    func testHistoryMergeIncludesIncomingAndOutgoingLocalRowsThroughTheMergeManager() async throws {
        let f = try FacadeFixture()
        let path = CallCodingPath(moduleName: "System", callName: "remark")
        let outgoing = TransactionHistoryItem(sender: f.address, receiver: "peer", status: .pending, txHash: "0x1111", timestamp: 101, fee: "0", blockNumber: 1, txIndex: 0, callPath: path, call: Data())
        let incoming = TransactionHistoryItem(sender: "peer", receiver: f.address, status: .pending, txHash: "0x2222", timestamp: 100, fee: "0", blockNumber: 1, txIndex: 1, callPath: path, call: Data())
        let operation = f.facade.createHistoryMergeOperation(dependingOn: historyRemote([]), localOperation: completed([incoming, outgoing]), pendingOperation: nil, feeAsset: f.facade.accountSettings.assets[0], address: f.address)
        let result = try await run(CompoundOperationWrapper(targetOperation: operation))
        equal(Set(result.historyItems.map(\.transactionId)), ["0x1111", "0x2222"])
        truth(result.historyItems.allSatisfy { $0.status == .pending })
    }
    func testHistoryMergePropagatesRemoteAndLocalReadErrors() async throws {
        let f = try FacadeFixture()
        let remote = BaseOperation<WalletRemoteHistoryData>(); remote.result = .failure(FacadeFailure.offline)
        await expectFailure { try await run(.init(targetOperation: f.facade.createHistoryMergeOperation(dependingOn: remote, localOperation: nil, pendingOperation: nil, feeAsset: f.facade.accountSettings.assets[0], address: f.address))) }
        let local = BaseOperation<[TransactionHistoryItem]>(); local.result = .failure(FacadeFailure.offline)
        await expectFailure { try await run(.init(targetOperation: f.facade.createHistoryMergeOperation(dependingOn: nil, localOperation: local, pendingOperation: nil, feeAsset: f.facade.accountSettings.assets[0], address: f.address))) }
    }
    func testHistoryMappingFiltersUnknownAssetsAndPreservesTheContinuation() async throws {
        let f = try FacadeFixture(), visible = historyData("known"), hidden = historyData("unknown", asset: "unknown")
        let merge = completed(TransactionHistoryMergeResult(historyItems: [hidden, visible], identifiersToRemove: []))
        let result = try await run(.init(targetOperation: f.facade.createHistoryMapOperation(dependingOn: merge, remoteOperation: historyRemote([], cursor: 7))))
        equal(result?.transactions, [visible]); equal(result?.context?[TransactionHistoryContext.cursor], "7"); equal(result?.context?[TransactionHistoryContext.isComplete], "false")
    }
    func testHistoryMappingClosesCompletedPagesAndDefaultsAMissingCursor() async throws {
        let f = try FacadeFixture(), merge = completed(TransactionHistoryMergeResult(historyItems: [], identifiersToRemove: []))
        let complete = try await run(.init(targetOperation: f.facade.createHistoryMapOperation(dependingOn: merge, remoteOperation: historyRemote([], complete: true))))
        XCTAssertNil(complete?.context)
        let partial = try await run(.init(targetOperation: f.facade.createHistoryMapOperation(dependingOn: merge, remoteOperation: historyRemote([], cursor: nil))))
        equal(partial?.context?[TransactionHistoryContext.cursor], "1")
    }
    private func decodePools(_ bytes: Data) throws -> [String]? {
        try JSONDecoder().decode(JSONScaleDecodable<AccountPools>.self, from: JSONEncoder().encode(bytes.toHex(includePrefix: true))).underlyingValue?.assetIds
    }
    func testPoolListDecoderSupportsCompactCountsLargerThan63() throws {
        let assets = (0..<64).map { Data(repeating: UInt8($0), count: 32) }
        let data = assets.reduce(into: Data([0x01, 0x01])) { $0.append($1) }
        equal(try decodePools(data), assets.map { $0.toHex(includePrefix: true) })
    }
    func testPoolListDecoderRejectsMissingDeclaredRows() {
        XCTAssertThrowsError(try decodePools(Data([0x08]) + Data(repeating: 1, count: 32)))
    }
    func testPoolListDecoderRejectsUndeclaredRows() {
        XCTAssertThrowsError(try decodePools(Data([0x00]) + Data(repeating: 1, count: 32)))
    }
    func testPoolListDecoderRejectsTrailingPartialAssetBytes() {
        XCTAssertThrowsError(try decodePools(Data([0x04]) + Data(repeating: 1, count: 33)))
    }
    func testPoolListDecoderAcceptsCanonicalEmptyVector() throws {
        equal(try decodePools(Data([0x00])), [])
    }
    func testPoolListDecoderRejectsOversizedCountWithoutAllocatingRows() {
        XCTAssertThrowsError(try decodePools(Data([0x03, 0xff, 0xff, 0xff, 0xff])))
    }

}

private enum FacadeFailure: Swift.Error { case offline }
private final class FacadeFixture {
    let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue
    let publicKey = Data(repeating: 0x42, count: 32)
    let reserveAccount = Data(repeating: 0x51, count: 32)
    let node = WalletNetworkOperationFactoryProtocolMock(), prices = FacadePrices(), contacts = FacadeContacts()
    let accounts = InMemoryDataProviderRepository<AccountItem>()
    let transactions = InMemoryDataProviderRepository<TransactionHistoryItem>()
    let chain = InMemoryDataProviderRepository<ChainStorageItem>()
    let assets = FacadeAssets(), farms = FacadeFarms(), engine = FacadeEngine()
    let address: String
    var facade: WalletNetworkFacade!
    init() throws {
        address = try SS58AddressFactory().addressFromAccountId(data: publicKey, type: SoraPassport.Chain.sora.addressType())
        facade = WalletNetworkFacade(accountSettings: WalletAccountSettings(accountId: publicKey.toHex(), assets: [WalletAsset(identifier: WalletAssetId.xor.rawValue, name: LocalizableResource { _ in "XOR" }, symbol: "XOR", precision: 18)]),
          nodeOperationFactory: node, coingeckoOperationFactory: prices,
          polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactory(engine: engine),
          chainStorage: AnyDataProviderRepository(chain), localStorageIdFactory: try ChainStorageIdFactory(chain: .sora),
          txStorage: AnyDataProviderRepository(transactions), contactsOperationFactory: contacts,
          accountsRepository: AnyDataProviderRepository(accounts), address: address, networkType: SoraPassport.Chain.sora.addressType(),
          assetManager: assets, totalPriceAssetId: nil, runtimeService: FacadeRuntime(),
          requestFactory: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager()),
          engine: engine, demeterFarmingService: farms)
    }
    func account(_ value: UInt8, name: String = "Fixture") throws -> AccountItem {
        let key = Data(repeating: value, count: 32)
        return AccountItem(address: try SS58AddressFactory().addressFromAccountId(data: key, type: SoraPassport.Chain.sora.addressType()), cryptoType: .sr25519, networkType: SoraPassport.Chain.sora.addressType(), username: name, publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: false)
    }
    func contact(_ value: UInt8, name: String? = nil) throws -> ContactItem {
        ContactItem(peerAddress: try account(value).address, peerName: name, targetAddress: address, updatedAt: 0)
    }
    func transfer() -> TransferInfo {
        TransferInfo(source: address, destination: String(repeating: "43", count: 32), amount: AmountDecimal(value: 1), asset: val, details: "", fees: [], context: [TransactionContextKeys.transactionType: TransactionType.outgoing.rawValue])
    }
    func prepared(hash: String? = nil) -> PreparedSora2TransferSubmission {
        let bytes = Data([1, 2, 3, 4])
        return PreparedSora2TransferSubmission(fee: 1, rawFee: "1000000000000000000", preparedExtrinsic: PreparedExtrinsicSubmission(data: bytes, hash: hash ?? (try! bytes.blake2b32().toHex(includePrefix: true))))
    }
    func liquidity() -> TransferInfo {
        TransferInfo(source: xor, destination: val, amount: AmountDecimal(value: 1), asset: xor, details: "", fees: [], context: [TransactionContextKeys.transactionType: TransactionType.liquidityAdd.rawValue])
    }
    func preparedLiquidity(includeCall: Bool = true, callName: String = "deposit_liquidity") throws -> PreparedLiquiditySubmission {
        let bytes = Data([5, 6, 7, 8])
        let call = RuntimeCall<JSON>(moduleName: CallCodingPath.depositLiquidity.moduleName, callName: callName, args: .dictionaryValue(["amount": .stringValue("123")]))
        let json = try JSONDecoder.scaleCompatible(snakeCase: false).decode(SoraPassport.JsonContainer.self, from: JSONEncoder.scaleCompatible().encode(SoraPassport.EncodingContainer(value: call))).value
        return PreparedLiquiditySubmission(fee: Decimal(string: "0.000000000000000017")!, rawFee: "17", preparedExtrinsic: PreparedExtrinsicSubmission(data: bytes, hash: try bytes.blake2b32().toHex(includePrefix: true), call: includeCall ? json : nil))
    }
    func propertiesKey() throws -> String { try StorageKeyFactory().poolPropertiesKey(baseAssetId: Data(hexStringSSF: xor), targetAssetId: Data(hexStringSSF: val)).toHex(includePrefix: true) }
    func providerKey() throws -> String { try StorageKeyFactory().poolProvidersKey(reservesAccountId: reserveAccount, accountId: publicKey).toHex(includePrefix: true) }
    func issuanceKey() throws -> String { try StorageKeyFactory().accountPoolTotalIssuancesKeyForId(reserveAccount).toHex(includePrefix: true) }
    func reservesKey() throws -> String { try StorageKeyFactory().poolReservesKey(baseAssetId: Data(hexStringSSF: xor), targetAssetId: Data(hexStringSSF: val)).toHex(includePrefix: true) }
    func pool(issuance: BigUInt = 20, targetRaw: BigUInt? = nil) throws {
        let unit = BigUInt(10).power(18)
        engine.values[try propertiesKey()] = (reserveAccount + Data(repeating: 0x52, count: 32)).toHex(includePrefix: true)
        engine.values[try providerKey()] = Self.u128(5 * unit).toHex(includePrefix: true)
        engine.values[try issuanceKey()] = Self.u128(issuance * unit).toHex(includePrefix: true)
        engine.values[try reservesKey()] = (Self.u128(200 * unit) + Self.u128(targetRaw ?? 400 * unit)).toHex(includePrefix: true)
    }
    private static func u128(_ value: BigUInt) -> Data {
        let bytes = Array(value.serialize().reversed())
        return Data(bytes + Array(repeating: 0, count: 16 - bytes.count))
    }
}
private final class FacadePrices: CoingeckoOperationFactoryProtocol {
    var requests = [[String]](), values = [PriceData](), failure: Swift.Error?
    func fetchPriceOperation(for tokenIds: [String]) -> BaseOperation<[PriceData]> {
        requests.append(tokenIds)
        return ClosureOperation { if let failure = self.failure { throw failure }; return self.values }
    }
}
private final class FacadeContacts: WalletContactOperationFactoryProtocol {
    var items = [ContactItem](), failure: Swift.Error?
    func saveByAddressOperation(_ address: String) -> CompoundOperationWrapper<Void> { XCTFail("Unexpected contact mutation"); return .init(targetOperation: ClosureOperation { () }) }
    func fetchContactsOperation() -> CompoundOperationWrapper<[ContactItem]> {
        .init(targetOperation: ClosureOperation { if let failure = self.failure { throw failure }; return self.items })
    }
}
private final class FacadeAssets: AssetManagerProtocol {
    static var networkAssets = [AssetInfo]()
    var items = [(WalletAssetId.xor, "XOR"), (.val, "VAL")].map { AssetInfo(id: $0.0.rawValue, symbol: $0.1, chainId: "", precision: 18, icon: nil, displayName: $0.1, visible: true) }
    func assetInfo(for identifier: String) -> AssetInfo? { items.first { $0.identifier == identifier } }
    func getAssetList() -> [AssetInfo]? { items }
    func updateAssetList(_ list: [AssetInfo]) { items = list }
    func saveAssetList(_ list: [AssetInfo]) { items = list }
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { UInt(items.count) }
    func setup(for accountSettings: SelectedWalletSettings) {}
}
private final class FacadeFarms: DemeterFarmingServiceProtocol {
    var failure: Swift.Error?, reads = [Data]()
    func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?) async -> [UserFarm] { [] }
    func loadUserFarmInfos(baseAssetId: String?, targetAssetId: String?, accountId: Data) async throws -> [UserFarm] { reads.append(accountId); if let failure { throw failure }; return [] }
    func getAllFarms() async throws -> [Farm] { [] }
    func getFarm(with id: String) -> Farm? { nil }
    func getFarmDetails(baseAssetId: String, poolAssetId: String, rewardAssetId: String) async throws -> [Farm] { [] }
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) { completion([]) }
}
private final class FacadeRuntime: SoraPassport.RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { XCTFail("Unexpected runtime fetch"); throw FacadeFailure.offline }
    }
}
private final class FacadeEngine: JSONRPCEngine {
    var url: URL?; var pendingEngineRequests: [JSONRPCRequest] { [] }
    var values = [String: String](), failures = Set<String>(), failAll = false
    var pairEnabled = false, pairFailure = false, pairRequests = 0
    private let lock = NSLock(); private var records = [[String]]()
    var queries: [[String]] { lock.lock(); defer { lock.unlock() }; return records }
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Swift.Error>) -> Void)?) throws -> UInt16 {
        if method == SoraPassport.RPCMethod.isPairEnabled {
            lock.lock(); pairRequests += 1; lock.unlock()
            let result = Result<T, Swift.Error> {
                if pairFailure { throw FacadeFailure.offline }
                return try JSONDecoder().decode(T.self, from: Data((pairEnabled ? "true" : "false").utf8))
            }
            DispatchQueue.global().async { closure?(result) }; return 1
        }
        let parameters = try JSONDecoder().decode([String].self, from: JSONEncoder().encode(params))
        lock.lock(); records.append(parameters); lock.unlock()
        let result = Result<T, Swift.Error> {
            if failAll || parameters.contains(where: { failures.contains($0) }) { throw FacadeFailure.offline }
            let value: Any = parameters.first.flatMap { values[$0] } ?? NSNull()
            return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]))
        }
        DispatchQueue.global().async { closure?(result) }; return 1
    }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Swift.Error, Bool) -> Void) throws -> UInt16 { XCTFail("Unexpected subscription"); throw FacadeFailure.offline }
    func cancelForIdentifier(_ identifier: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_ subscription: JSONRPCSubscribing) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ identifier: UInt16) throws {}
}

private struct FacadeRemoteHistory: WalletRemoteHistoryItemProtocol {
    let id: String
    let transaction: AssetTransactionData?
    var identifier: String { id }; var itemBlockNumber: UInt64 { 1 }; var itemExtrinsicIndex: UInt16 { 0 }
    var extrinsicHash: String? { id }; var itemTimestamp: Int64 { 100 }; var label: WalletRemoteHistorySourceLabel { .extrinsics }
    func createTransactionForAddress(_ address: String, networkType: SNAddressType, asset: WalletAsset, addressFactory: SS58AddressFactoryProtocol) -> AssetTransactionData? { transaction }
}

final class HistoryFilterBoundaryTests: XCTestCase {
    private let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue
    private func row(_ path: KmmCallCodingPath, _ values: [String: String] = [:]) -> TxHistoryItem {
        TxHistoryItem(id: "0x" + String(repeating: "11", count: 32), blockHash: "0x" + String(repeating: "22", count: 32), module: path.moduleName,
            method: path.callName, timestamp: "100", networkFee: "7", success: true,
            data: values.map { TxHistoryItemParam(paramName: $0.key, paramValue: $0.value) }, nestedData: nil)
    }
    private func requestedFilter(asset: String?) throws -> HistoryService.HistoryFilter? {
        var captured: HistoryService.HistoryFilter?
        var received = false
        let done = expectation(description: "remote history request carries its asset predicate")
        let service = HistoryService(operationManager: OperationManager(), address: "fixture", assets: [],
            localStorage: BoundaryHistoryStorage(), readRemote: { _, _, _, filter in
                captured = filter; received = true
                return .init(items: [], endReached: true)
            }, readJournal: { [] })
        service.getHistory(count: 10, assetId: asset) { result in
            switch result { case .success(let rows): XCTAssertTrue(rows.isEmpty); case .failure(let error): XCTFail("Unexpected fixture read failure: \(error)") }; done.fulfill()
        }
        wait(for: [done], timeout: 2)
        XCTAssertTrue(received)
        return captured
    }
    private func matches(_ asset: String, _ row: TxHistoryItem) throws -> Bool {
        try XCTUnwrap(requestedFilter(asset: asset))(row).boolValue
    }
    func testUnfilteredHistoryDoesNotInstallAnAssetPredicate() throws { XCTAssertNil(try requestedFilter(asset: nil)) }
    func testEverySupportedTransferSpellingFiltersOnItsAssetId() throws {
        for path: KmmCallCodingPath in [.transfer, .adarTransfer, .transferKeepAlive] {
            let item = row(path, ["assetId": val]); XCTAssertTrue(try matches(val, item)); XCTAssertFalse(try matches(xor, item))
        }
    }
    func testReferralOperationsAppearOnlyInTheXorAssetHistory() throws {
        for path: KmmCallCodingPath in [.bondReferralBalance, .unbondReferralBalance, .setReferral] {
            XCTAssertTrue(try matches(xor, row(path))); XCTAssertFalse(try matches(val, row(path)))
        }
    }
    func testSwapsAppearInBothInputAndOutputAssetsButNotUnrelatedAssets() throws {
        let item = row(.swap, ["baseAssetId": xor, "targetAssetId": val])
        XCTAssertTrue(try matches(xor, item)); XCTAssertTrue(try matches(val, item)); XCTAssertFalse(try matches("unrelated", item))
    }
    func testLiquidityDepositsAndWithdrawalsAppearInBothConstituentAssets() throws {
        for path: KmmCallCodingPath in [.depositLiquidity, .withdrawLiquidity] {
            let item = row(path, ["baseAssetId": xor, "targetAssetId": val])
            XCTAssertTrue(try matches(xor, item)); XCTAssertTrue(try matches(val, item)); XCTAssertFalse(try matches("unrelated", item))
        }
    }
    func testAtomicAndOrdinaryLiquidityBatchesUseTheirOuterAssetParameters() throws {
        for path: KmmCallCodingPath in [.batchUtility, .batchAllUtility] {
            let item = row(path, ["input_asset_a": xor, "input_asset_b": val])
            XCTAssertTrue(try matches(xor, item)); XCTAssertTrue(try matches(val, item)); XCTAssertFalse(try matches("unrelated", item))
        }
    }
    func testRewardClaimsUseTheRewardAssetParameter() throws {
        let item = row(.getRewards, ["assetId": val]); XCTAssertTrue(try matches(val, item)); XCTAssertFalse(try matches(xor, item))
    }
    func testFarmDepositsAndWithdrawalsMatchAllThreeQualifiedAssets() throws {
        for path: KmmCallCodingPath in [.farmDeposit, .farmWithdraw] {
            let item = row(path, ["assetId": val, "baseAssetId": xor, "rewardAssetId": "reward"])
            for asset in [xor, val, "reward"] { XCTAssertTrue(try matches(asset, item)) }
            XCTAssertFalse(try matches("unrelated", item))
        }
    }
    func testMissingAssetParametersAndUnknownCallsDoNotMatchAnAsset() throws {
        for path: KmmCallCodingPath in [.transfer, .swap, .depositLiquidity, .withdrawLiquidity, .batchUtility, .getRewards, .farmDeposit, .farmWithdraw, .init(moduleName: "unknown", callName: "unknown")] {
            XCTAssertFalse(try matches(xor, row(path)))
        }
    }
    private func service(fails: Bool = false) -> HistoryService {
        HistoryService(operationManager: OperationManager(), address: "fixture", assets: [], localStorage: BoundaryHistoryStorage(),
            readRemote: { address, count, page, _ in
                XCTAssertEqual(address, "fixture"); XCTAssertEqual(count, 10)
                if fails { throw URLError(.timedOut) }
                return .init(items: [], endReached: page == 2, mayOmitIncomingTransfers: true, cachedAt: Date(timeIntervalSince1970: 100))
            }, readJournal: { [] })
    }
    func testLegacyHistoryCompletionDeliversAnAuthoritativeEmptySuccessOnce() async {
        let s = service(), done = expectation(description: "history callback")
        s.getHistory(count: 10, assetId: nil) { result in
            do { XCTAssertTrue(try result.get().isEmpty) } catch { XCTFail("Unexpected history failure: \(error)") }; done.fulfill()
        }
        await fulfillment(of: [done], timeout: 2)
    }
    func testLegacyHistoryCompletionPropagatesReadFailure() async {
        let s = service(fails: true), done = expectation(description: "history error callback")
        s.getHistory(count: 10, assetId: nil) { result in
            guard case .failure(let e) = result else { XCTFail("Failure became success"); done.fulfill(); return }
            XCTAssertEqual((e as? URLError)?.code, .timedOut); done.fulfill()
        }
        await fulfillment(of: [done], timeout: 2)
    }
    func testLegacyPageCompletionPreservesPaginationAndStaleReadQualification() async {
        let s = service(), done = expectation(description: "page callback")
        s.getPageHistory(count: 10, page: 2, assetId: nil) { result in
            do {
                let p = try result.get(); XCTAssertTrue(p.transactions.isEmpty); XCTAssertTrue(p.endReached)
                XCTAssertTrue(p.mayOmitIncomingTransfers); XCTAssertEqual(p.cachedAt, Date(timeIntervalSince1970: 100))
            } catch { XCTFail("Unexpected page failure: \(error)") }; done.fulfill()
        }
        await fulfillment(of: [done], timeout: 2)
    }
    func testLegacyPageCompletionPropagatesReadFailure() async {
        let s = service(fails: true), done = expectation(description: "page error callback")
        s.getPageHistory(count: 10, page: 2, assetId: nil) { result in
            guard case .failure(let e) = result else { XCTFail("Failure became success"); done.fulfill(); return }
            XCTAssertEqual((e as? URLError)?.code, .timedOut); done.fulfill()
        }
        await fulfillment(of: [done], timeout: 2)
    }
}
private final class BoundaryHistoryStorage: LocalTransactionStorageProtocol { var transactions: [String: [Transaction]] = [:] }

extension WalletFacadeFlowTests {
    private func pair(_ f: FacadeFixture, dex: String? = "0", base: String? = nil) -> TransferInfo {
        TransferInfo(source: base ?? f.xor, destination: f.val, amount: AmountDecimal(value: 1), asset: f.xor, details: "", fees: [], context: dex.map { [TransactionContextKeys.dex: $0] })
    }
    func testLiquidityPairCreationRejectsInvalidDexIdentifiersBeforeStorageReads() throws {
        let f = try FacadeFixture()
        for dex: String? in [nil, "", "-1", "4294967296", "x"] { XCTAssertThrowsError(try f.facade.createLiquidityPairIfNeeded(pair(f, dex: dex))) }
        XCTAssertTrue(f.engine.queries.isEmpty)
    }
    func testAnInitializedLiquidityPoolDoesNotCreateAnotherPair() throws {
        let f = try FacadeFixture(); try f.pool()
        XCTAssertNil(try f.facade.createLiquidityPairIfNeeded(pair(f)))
        XCTAssertEqual(f.engine.queries, [[try f.propertiesKey()]])
    }
    func testFailedPoolReadCannotBeMistakenForAnAbsentPool() throws {
        let f = try FacadeFixture(); f.engine.failAll = true
        XCTAssertThrowsError(try f.facade.createLiquidityPairIfNeeded(pair(f)))
        XCTAssertEqual(f.engine.queries.count, 1)
    }
    func testPairLookupFailureCannotLaunchInitialization() throws {
        let f = try FacadeFixture(); f.engine.pairFailure = true
        XCTAssertThrowsError(try f.facade.createLiquidityPairIfNeeded(pair(f)))
        XCTAssertEqual(f.engine.pairRequests, 1)
    }
    func testMissingConcreteExtrinsicFactoryCannotInitializeAnUnregisteredPair() throws {
        let f = try FacadeFixture(); f.engine.pairEnabled = false
        XCTAssertThrowsError(try f.facade.createLiquidityPairIfNeeded(pair(f)))
        XCTAssertEqual(f.engine.pairRequests, 1)
    }
    func testMissingConcreteExtrinsicFactoryCannotInitializeARegisteredPair() throws {
        let f = try FacadeFixture(); f.engine.pairEnabled = true
        XCTAssertThrowsError(try f.facade.createLiquidityPairIfNeeded(pair(f)))
        XCTAssertEqual(f.engine.pairRequests, 1)
    }
}
