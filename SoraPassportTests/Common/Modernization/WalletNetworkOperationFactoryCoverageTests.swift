// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SoraFoundation
import SSFModels
import SSFUtils
import SSFStorageQueryKitFixed
import XCTest
@testable import SoraPassport

extension WalletNetworkOperationFactoryCoverageTests {
    private func pendingHistory(_ info: TransferInfo, sender: String = "bound-history-owner") throws -> TransactionHistoryItem {
        try TransactionHistoryItem.createFromTransferInfo(info, transactionHash: Data([1, 2, 3]), senderAddress: sender,
            networkType: 69, addressFactory: SS58AddressFactory())
    }
    private func pendingCall<T: Decodable>(_ item: TransactionHistoryItem, as type: T.Type) throws -> T {
        try JSONDecoder.scaleCompatible(snakeCase: false).decode(type, from: XCTUnwrap(item.call))
    }
    func testPendingSwapHistoryKeepsTheReviewedAmountsAndMarket() throws {
        let history = try pendingHistory(product(.swap))
        let call = try pendingCall(history, as: RuntimeCall<SwapCall>.self)
        XCTAssertEqual(call.args.inputAssetId.value, xor); XCTAssertEqual(call.args.outputAssetId.value, val)
        XCTAssertEqual(call.args.amount[.desiredInput]?.desired, BigUInt("1000000000000000000"))
        XCTAssertEqual(call.args.amount[.desiredInput]?.slip, BigUInt("1990000000000000000"))
        XCTAssertEqual(call.args.liquiditySourceType, [["XYKPool", nil]])
        XCTAssertEqual(history.sender, "bound-history-owner"); XCTAssertEqual(history.receiver, val)
        XCTAssertEqual(history.txHash, "0x010203"); XCTAssertEqual(history.status, .pending)
        XCTAssertNil(history.blockNumber); XCTAssertNil(history.txIndex)
    }
    func testPendingSwapHistoryRejectsIncompleteOrInconsistentReviewContext() {
        for changes in [[TransactionContextKeys.marketType: "unknown"], [TransactionContextKeys.desire: "invalid"],
                        [TransactionContextKeys.minMaxValue: "1"], [TransactionContextKeys.slippage: "invalid"]] {
            XCTAssertThrowsError(try pendingHistory(product(.swap, changes: changes)))
        }
    }
    func testPendingClaimHistoryKeepsBothAssetsRewardAssetAndFarmFlag() throws {
        for farm in ["0", "1"] {
            let history = try pendingHistory(product(.demeterClaimReward, changes: [TransactionContextKeys.isFarm: farm]))
            let call = try pendingCall(history, as: RuntimeCall<DemeterFarmingClaimRewardCall>.self)
            XCTAssertEqual(call.callName, "get_rewards"); XCTAssertEqual(call.args.baseAssetId.value, xor)
            XCTAssertEqual(call.args.targetAssetId.value, val); XCTAssertEqual(call.args.rewardAssetId.value, WalletAssetId.pswap.rawValue)
            XCTAssertEqual(call.args.isFarm, farm == "1")
        }
    }
    func testPendingFarmDepositKeepsEveryAtomicUnit() throws {
        let history = try pendingHistory(product(.demeterDeposit, amount: Decimal(string: "1.234567890123456789")!))
        let call = try pendingCall(history, as: RuntimeCall<DemeterFarmingDepositLiquidityCall>.self)
        XCTAssertEqual(call.callName, "deposit"); XCTAssertEqual(call.args.amount, BigUInt("1234567890123456789"))
        XCTAssertEqual(call.args.baseAssetId.value, xor); XCTAssertEqual(call.args.targetAssetId.value, val)
        XCTAssertTrue(call.args.isFarm)
    }
    func testPendingFarmWithdrawalKeepsOneAtomicUnitAndNonFarmFlag() throws {
        let history = try pendingHistory(product(.demeterWithdraw, amount: Decimal(string: "0.000000000000000001")!, changes: [TransactionContextKeys.isFarm: "0"]))
        let call = try pendingCall(history, as: RuntimeCall<DemeterFarmingWithdrawLiquidityCall>.self)
        XCTAssertEqual(call.callName, "withdraw"); XCTAssertEqual(call.args.amount, 1); XCTAssertFalse(call.args.isFarm)
        XCTAssertEqual(call.args.rewardAssetId.value, WalletAssetId.pswap.rawValue)
    }
    func testPendingFarmHistoryCannotInventMissingPairOrRewardContext() {
        for type in [TransactionType.demeterDeposit, .demeterWithdraw, .demeterClaimReward] {
            for info in [product(type, source: ""), product(type, destination: ""),
                         product(type, changes: [TransactionContextKeys.rewardAsset: ""]),
                         product(type, changes: [TransactionContextKeys.isFarm: "true"])] {
                XCTAssertThrowsError(try pendingHistory(info))
            }
        }
    }
    func testPendingFarmHistoryRejectsNonpositiveAndSubAtomicAmounts() {
        for type in [TransactionType.demeterDeposit, .demeterWithdraw] {
            for amount in [Decimal.zero, -1, Decimal(string: "0.0000000000000000001")!] {
                XCTAssertThrowsError(try pendingHistory(product(type, amount: amount)))
            }
        }
    }
    func testPendingTransferHistoryRequiresSenderAssetAndPositiveAtomicAmount() {
        XCTAssertThrowsError(try pendingHistory(transfer(), sender: ""))
        XCTAssertThrowsError(try pendingHistory(transfer(asset: "")))
        for amount in [Decimal.zero, -1, Decimal(string: "0.0000000000000000001")!] {
            XCTAssertThrowsError(try pendingHistory(transfer(amount: amount)))
        }
    }
    func testPendingHistoryUsesOnlyTheNetworkFeeAndConvertsItExactly() throws {
        let original = transfer()
        let fees = [Fee(value: AmountDecimal(value: 99), feeDescription: FeeDescription(identifier: "provider", assetId: xor, type: "provider", parameters: [])),
                    Fee(value: AmountDecimal(string: "0.000000000000000007")!, feeDescription: FeeDescription(identifier: "network", assetId: xor, type: "fee", parameters: []))]
        let info = TransferInfo(source: original.source, destination: original.destination, amount: original.amount,
            asset: original.asset, details: original.details, fees: fees, context: original.context)
        XCTAssertEqual(try pendingHistory(info).fee, "7")
        XCTAssertEqual(try pendingHistory(original).fee, "0")
    }
}

/// Runs the production factory and call constructors with an in-memory service boundary.
/// The recording service executes each builder closure; it never signs or contacts a node.
@MainActor
final class WalletNetworkOperationFactoryCoverageTests: XCTestCase {
    private let xor = WalletAssetId.xor.rawValue
    private let val = WalletAssetId.val.rawValue
    private let receiver = String(repeating: "03", count: 32)
    private let queue = OperationQueue()
    private var previousSelectedAccount: AccountItem?
    override func setUp() { super.setUp(); previousSelectedAccount = SelectedWalletSettings.shared.currentAccount }
    override func tearDown() { SelectedWalletSettings.shared.commitInternalValue(previousSelectedAccount); super.tearDown() }

    private func asset(_ id: String, precision: Int16 = 18) -> WalletAsset {
        WalletAsset(identifier: id, name: LocalizableResource { _ in id }, symbol: id, precision: precision)
    }
    private func make(assets: [WalletAsset]? = nil, accountSigner: SigningWrapperProtocol? = nil) throws -> (WalletNetworkOperationFactory, FactoryExtrinsics) {
        let service = FactoryExtrinsics()
        let signer = accountSigner ?? FactoryNoSigner()
        return (WalletNetworkOperationFactory(
            engine: FactoryNoEngine(),
            requestFactory: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager()),
            runtimeService: FactoryNoRuntime(),
            accountSettings: WalletAccountSettings(accountId: receiver, assets: assets ?? [asset(xor), asset(val, precision: 6)]),
            cryptoType: .sr25519, accountSigner: signer, extrinsicService: service, dummySigner: signer,
            chainStorage: AnyDataProviderRepository(FactoryEmptyStorage()),
            localStorageIdFactory: try ChainStorageIdFactory(chain: .sora)), service)
    }
    private func transfer(amount: Decimal = 1, asset: String? = nil, destination: String? = nil,
                          type: TransactionType = .outgoing) -> TransferInfo {
        TransferInfo(source: "sender", destination: destination ?? receiver, amount: AmountDecimal(value: amount),
                     asset: asset ?? val, details: "", fees: [],
                     context: [TransactionContextKeys.transactionType: type.rawValue])
    }
    private func liquidity(_ type: TransactionType = .liquidityAdd, changes: [String: String] = [:],
                           source: String? = nil, destination: String? = nil) -> TransferInfo {
        var context = [TransactionContextKeys.transactionType: type.rawValue,
                       TransactionContextKeys.firstAssetAmount: "1.234567890123456789",
                       TransactionContextKeys.secondAssetAmount: "2.345678",
                       TransactionContextKeys.slippage: "0.5", TransactionContextKeys.dex: "0",
                       TransactionContextKeys.firstReserves: "10", TransactionContextKeys.totalIssuances: "30"]
        context.merge(changes) { _, new in new }
        return TransferInfo(source: source ?? xor, destination: destination ?? val,
                            amount: AmountDecimal(value: 1), asset: xor, details: "", fees: [], context: context)
    }
    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) async throws -> T {
        let done = expectation(description: "factory operation completed")
        wrapper.targetOperation.completionBlock = { done.fulfill() }
        wrapper.allOperations.forEach { queue.addOperation($0) }
        await fulfillment(of: [done], timeout: 3)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }
    private func expectFailure<T>(_ expected: WalletNetworkOperationFactoryError,
                                  _ operation: () async throws -> T,
                                  file: StaticString = #filePath, line: UInt = #line) async {
        do { _ = try await operation(); XCTFail("Expected \(expected)", file: file, line: line) }
        catch let error as WalletNetworkOperationFactoryError {
            XCTAssertEqual(String(describing: error), String(describing: expected), file: file, line: line)
        } catch { XCTFail("Unexpected \(error)", file: file, line: line) }
    }

    func testTransferFeeUsesTheAssetPrecisionAndCanonicalXorFee() async throws {
        let (factory, service) = try make()
        let fee = try await factory.estimateTransferFee(for: transfer(amount: Decimal(string: "1.234567")!))
        XCTAssertEqual(fee, Decimal(string: "0.000000000000000007"))
        let call = try XCTUnwrap(service.builders.first?.calls.first).map(to: RuntimeCall<SoraTransferCall>.self)
        XCTAssertEqual(call.callName, "transfer")
        XCTAssertEqual(call.args.amount, 1_234_567)
        XCTAssertEqual(call.args.receiver, Data(repeating: 3, count: 32))
        XCTAssertEqual(call.args.assetId.value, val)
        XCTAssertEqual(service.estimateCount, 1)
    }
    func testTransferFeeRejectsZeroNegativeAndSubAtomicAmountsBeforeService() async throws {
        for amount in [Decimal.zero, Decimal(-1), Decimal(string: "0.0000001")!] {
            let (factory, service) = try make()
            await expectFailure(.invalidAmount) { try await factory.estimateTransferFee(for: transfer(amount: amount)) }
            XCTAssertEqual(service.estimateCount, 0)
        }
    }
    func testTransferFeeRejectsUnknownAssetOrMissingReceiverBeforeService() async throws {
        for info in [transfer(asset: "unknown"), transfer(destination: "")] {
            let (factory, service) = try make()
            await expectFailure(.invalidAsset) { try await factory.estimateTransferFee(for: info) }
            XCTAssertEqual(service.estimateCount, 0)
        }
    }
    func testMalformedReceiverFailsWhileConstructingTheExactCall() async throws {
        let (factory, service) = try make()
        do { _ = try await factory.estimateTransferFee(for: transfer(destination: "not-hex")); XCTFail("Invalid destination accepted") }
        catch { XCTAssertEqual(service.estimateCount, 1); XCTAssertTrue(service.builders.isEmpty) }
    }
    func testTransferFeeDoesNotAcceptAnotherTransactionType() async throws {
        let (factory, service) = try make()
        await expectFailure(.invalidContext) { try await factory.estimateTransferFee(for: transfer(type: .swap)) }
        XCTAssertEqual(service.estimateCount, 0)
    }
    func testTransferFeeRejectsMalformedZeroOrNegativeNodeFees() async throws {
        for raw in ["", "invalid", "0", "-1", "1.2"] {
            let (factory, service) = try make(); service.rawFee = raw
            await expectFailure(.invalidFee) { try await factory.estimateTransferFee(for: transfer()) }
        }
    }
    func testTransferFeeRequiresExactlyOneCanonicalFeeAsset() async throws {
        for assets in [[asset(val)], [asset(xor), asset(xor), asset(val)]] {
            let (factory, _) = try make(assets: assets)
            await expectFailure(.invalidFee) { try await factory.estimateTransferFee(for: transfer()) }
        }
    }
    func testTransferFeePropagatesServiceFailure() async throws {
        let (factory, service) = try make(); service.failure = FactoryBoundaryError.offline
        do { _ = try await factory.estimateTransferFee(for: transfer()); XCTFail("Expected offline") }
        catch { XCTAssertTrue(error is FactoryBoundaryError) }
    }
    func testOrdinaryTransferCannotUseLegacySubmission() async throws {
        let (factory, service) = try make()
        await expectFailure(.invalidContext) { try await run(factory.transferOperation(transfer())) }
        XCTAssertEqual(service.submitCount, 0)
    }

    func testLiquidityDepositPreservesIndependentAssetPrecisionAndFloorsMinimums() async throws {
        let (factory, service) = try make()
        let fee = try await factory.estimateLiquidityFee(for: liquidity())
        XCTAssertEqual(fee, Decimal(string: "0.000000000000000007"))
        let call = try XCTUnwrap(service.builders.first?.calls.first).map(to: RuntimeCall<DepositLiquidityCall>.self)
        XCTAssertEqual(call.callName, "deposit_liquidity")
        XCTAssertEqual(call.args.dexId, "0")
        XCTAssertEqual(call.args.desiredA, BigUInt("1234567890123456789"))
        XCTAssertEqual(call.args.desiredB, 2_345_678)
        XCTAssertEqual(call.args.minA, BigUInt("1228395050672839505"))
        XCTAssertEqual(call.args.minB, 2_333_949)
        XCTAssertEqual(call.args.assetA.value, xor)
        XCTAssertEqual(call.args.assetB.value, val)
    }
    func testFirstDepositIntoAnExistingPairUsesAtomicInitializeThenDeposit() async throws {
        let (factory, service) = try make()
        _ = try await factory.estimateLiquidityFee(for: liquidity(.liquidityAddToExistingPoolFirstTime))
        let builder = try XCTUnwrap(service.builders.first)
        XCTAssertEqual(builder.atomicSelections, [true]); XCTAssertEqual(builder.calls.count, 2)
        XCTAssertEqual(try builder.calls[0].map(to: RuntimeCall<InitializePoolCall>.self).callName, "initialize_pool")
        XCTAssertEqual(try builder.calls[1].map(to: RuntimeCall<DepositLiquidityCall>.self).callName, "deposit_liquidity")
    }
    func testNewPairDepositUsesAtomicRegisterInitializeDepositOrdering() async throws {
        let (factory, service) = try make()
        _ = try await factory.estimateLiquidityFee(for: liquidity(.liquidityAddNewPool))
        let builder = try XCTUnwrap(service.builders.first)
        XCTAssertEqual(builder.atomicSelections, [true]); XCTAssertEqual(builder.calls.count, 3)
        XCTAssertEqual(try builder.calls[0].map(to: RuntimeCall<PairRegisterCall>.self).callName, "register")
        XCTAssertEqual(try builder.calls[1].map(to: RuntimeCall<InitializePoolCall>.self).callName, "initialize_pool")
        XCTAssertEqual(try builder.calls[2].map(to: RuntimeCall<DepositLiquidityCall>.self).callName, "deposit_liquidity")
    }
    func testLiquidityRemovalUsesReserveShareAndFlooredTokenMinimums() async throws {
        let (factory, service) = try make()
        _ = try await factory.estimateLiquidityFee(for: liquidity(.liquidityRemoval,
            changes: [TransactionContextKeys.firstAssetAmount: "2", TransactionContextKeys.secondAssetAmount: "4.123456"]))
        let call = try XCTUnwrap(service.builders.first?.calls.first).map(to: RuntimeCall<WithdrawLiquidityCall>.self)
        XCTAssertEqual(call.callName, "withdraw_liquidity")
        XCTAssertEqual(call.args.assetDesired, BigUInt("6000000000000000000"))
        XCTAssertEqual(call.args.minA, BigUInt("1990000000000000000"))
        XCTAssertEqual(call.args.minB, 4_102_838)
    }
    func testLiquidityRejectsMissingOrIdenticalAssetsBeforeService() async throws {
        for info in [liquidity(source: "unknown"), liquidity(destination: "unknown"), liquidity(destination: xor)] {
            let (factory, service) = try make()
            await expectFailure(.invalidAsset) { try await factory.estimateLiquidityFee(for: info) }
            XCTAssertEqual(service.estimateCount, 0)
        }
    }
    func testLiquidityRejectsUnsupportedTransactionTypes() async throws {
        let (factory, service) = try make()
        await expectFailure(.invalidContext) { try await factory.estimateLiquidityFee(for: liquidity(.swap)) }
        XCTAssertEqual(service.estimateCount, 0)
    }
    func testLiquidityDepositRejectsPartialDecimalStrings() async throws {
        for key in [TransactionContextKeys.firstAssetAmount, TransactionContextKeys.secondAssetAmount] {
            let (factory, service) = try make()
            await expectFailure(.invalidContext) { try await factory.estimateLiquidityFee(for: liquidity(changes: [key: "2trailing"])) }
            XCTAssertEqual(service.estimateCount, 0)
        }
    }
    func testLiquidityRemovalRejectsPartialDecimalAmountStrings() async throws {
        for key in [TransactionContextKeys.firstAssetAmount, TransactionContextKeys.secondAssetAmount] {
            let (factory, service) = try make()
            await expectFailure(.invalidContext) { try await factory.estimateLiquidityFee(for: liquidity(.liquidityRemoval, changes: [key: "2trailing"])) }
            XCTAssertEqual(service.estimateCount, 0)
        }
    }
    func testLiquidityRemovalRejectsPartialDecimalReserveStrings() async throws {
        for key in [TransactionContextKeys.firstReserves, TransactionContextKeys.totalIssuances] {
            let (factory, service) = try make()
            await expectFailure(.invalidContext) { try await factory.estimateLiquidityFee(for: liquidity(.liquidityRemoval, changes: [key: "20trailing"])) }
            XCTAssertEqual(service.estimateCount, 0)
        }
    }
    func testLiquidityRejectsInvalidSlippageBeforeService() async throws {
        for raw in ["0", "10.01", "-1", "0.5junk"] {
            let (factory, service) = try make()
            await expectFailure(.invalidContext) { try await factory.estimateLiquidityFee(for: liquidity(changes: [TransactionContextKeys.slippage: raw])) }
            XCTAssertEqual(service.estimateCount, 0)
        }
    }
    func testLiquidityRejectsZeroOrNegativeInputsBeforeService() async throws {
        for type in [TransactionType.liquidityAdd, .liquidityRemoval] {
            for raw in ["0", "-1"] {
                let (factory, service) = try make()
                await expectFailure(.invalidAmount) { try await factory.estimateLiquidityFee(for: liquidity(type, changes: [TransactionContextKeys.firstAssetAmount: raw])) }
                XCTAssertEqual(service.estimateCount, 0)
            }
        }
    }
    func testLiquidityRemovalRejectsZeroReservesAndIssuance() async throws {
        for key in [TransactionContextKeys.firstReserves, TransactionContextKeys.totalIssuances] {
            let (factory, service) = try make()
            await expectFailure(.invalidAmount) { try await factory.estimateLiquidityFee(for: liquidity(.liquidityRemoval, changes: [key: "0"])) }
            XCTAssertEqual(service.estimateCount, 0)
        }
    }
    func testLiquidityRejectsAmountsWhoseMinimumRoundsToZero() async throws {
        let (factory, service) = try make()
        await expectFailure(.invalidAmount) { try await factory.estimateLiquidityFee(for: liquidity(changes: [TransactionContextKeys.secondAssetAmount: "0.000001"])) }
        XCTAssertEqual(service.estimateCount, 0)
    }
    func testLiquidityFeeRequiresAnUnambiguousCanonicalFeeAsset() async throws {
        let (factory, _) = try make(assets: [asset(xor), asset(xor), asset(val)])
        await expectFailure(.invalidFee) { try await factory.estimateLiquidityFee(for: liquidity()) }
    }
    func testLiquidityFeeRejectsMalformedAndZeroFees() async throws {
        for raw in ["0", "-1", "bad", "1.5"] {
            let (factory, service) = try make(); service.rawFee = raw
            await expectFailure(.invalidFee) { try await factory.estimateLiquidityFee(for: liquidity()) }
        }
    }

    func testPrepareTransferPreservesExactFeeHashAndCall() async throws {
        let (factory, service) = try make(); var validations = 0
        let prepared = try await factory.prepareTransferSubmission(for: transfer(amount: 2)) { validations += 1 }
        XCTAssertEqual(validations, 1); XCTAssertEqual(service.prepareCount, 1)
        XCTAssertEqual(prepared.rawFee, "7"); XCTAssertEqual(prepared.transactionHash, service.prepared?.hash)
        XCTAssertEqual(prepared.fee, Decimal(string: "0.000000000000000007"))
        XCTAssertEqual(try service.builders[0].calls[0].map(to: RuntimeCall<SoraTransferCall>.self).args.amount, 2_000_000)
        XCTAssertNoThrow(try prepared.preparedExtrinsic.consumeForTransport())
        XCTAssertThrowsError(try prepared.preparedExtrinsic.consumeForTransport())
    }
    func testPrepareLiquidityPreservesExactBatchAndFee() async throws {
        let (factory, service) = try make(); var validations = 0
        let prepared = try await factory.prepareLiquiditySubmission(for: liquidity(.liquidityAddNewPool)) { validations += 1 }
        XCTAssertEqual(validations, 1); XCTAssertEqual(service.prepareCount, 1)
        XCTAssertEqual(service.builders[0].calls.count, 3); XCTAssertEqual(service.builders[0].atomicSelections, [true])
        XCTAssertEqual(prepared.rawFee, "7"); XCTAssertEqual(prepared.transactionHash, service.prepared?.hash)
        XCTAssertEqual(prepared.fee, Decimal(string: "0.000000000000000007"))
        prepared.discard(); XCTAssertThrowsError(try prepared.preparedExtrinsic.consumeForTransport())
    }
    func testPrepareTransferRequiresFeeAssetBeforeSigning() async throws {
        let (factory, service) = try make(assets: [asset(val)])
        await expectFailure(.invalidFee) { try await factory.prepareTransferSubmission(for: transfer()) {} }
        XCTAssertEqual(service.prepareCount, 0)
    }
    func testPrepareLiquidityRejectsDuplicateFeeAssetsBeforeSigning() async throws {
        let (factory, service) = try make(assets: [asset(xor), asset(xor), asset(val)])
        await expectFailure(.invalidFee) { try await factory.prepareLiquiditySubmission(for: liquidity()) {} }
        XCTAssertEqual(service.prepareCount, 0)
    }
    func testPrepareTransferDoesNotAcceptSwapContext() async throws {
        let (factory, service) = try make()
        await expectFailure(.invalidContext) { try await factory.prepareTransferSubmission(for: transfer(type: .swap)) {} }
        XCTAssertEqual(service.prepareCount, 0)
    }
    func testFailedPreSigningValidationStopsPreparation() async throws {
        let (factory, service) = try make()
        do { _ = try await factory.prepareTransferSubmission(for: transfer()) { throw FactoryBoundaryError.offline }; XCTFail("Expected validation failure") }
        catch { XCTAssertTrue(error is FactoryBoundaryError); XCTAssertNil(service.prepared) }
    }
    func testInvalidTransferFeeDiscardsPreparedBytes() async throws {
        let (factory, service) = try make(); service.rawFee = "0"
        await expectFailure(.invalidFee) { try await factory.prepareTransferSubmission(for: transfer()) {} }
        let prepared = try XCTUnwrap(service.prepared)
        XCTAssertThrowsError(try prepared.consumeForTransport())
    }
    func testInvalidLiquidityFeeDiscardsPreparedBytes() async throws {
        let (factory, service) = try make(); service.rawFee = "invalid"
        await expectFailure(.invalidFee) { try await factory.prepareLiquiditySubmission(for: liquidity()) {} }
        let prepared = try XCTUnwrap(service.prepared)
        XCTAssertThrowsError(try prepared.consumeForTransport())
    }
    func testCancellationAfterTransferPreparationDiscardsBytesAndCancelsCall() async throws {
        let (factory, service) = try make(); service.cancelAfterPrepare = true
        let task = Task { try await factory.prepareTransferSubmission(for: transfer()) {} }
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(service.call.cancelled)
        XCTAssertThrowsError(try XCTUnwrap(service.prepared).consumeForTransport())
    }
    func testCancellationAfterLiquidityPreparationDiscardsBytesAndCancelsCall() async throws {
        let (factory, service) = try make(); service.cancelAfterPrepare = true
        let task = Task { try await factory.prepareLiquiditySubmission(for: liquidity()) {} }
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(service.call.cancelled)
        XCTAssertThrowsError(try XCTUnwrap(service.prepared).consumeForTransport())
    }
    func testAlreadyCancelledTransferDoesNotReachFeeService() async throws {
        let (factory, service) = try make()
        let task = Task { withUnsafeCurrentTask { $0?.cancel() }; return try await factory.estimateTransferFee(for: transfer()) }
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(service.estimateCount, 0)
    }
    func testPreparedTransferRejectsNonLifecycleSignerBeforeTransportAndDiscardsBytes() async throws {
        let (factory, service) = try make()
        let prepared = try await factory.prepareTransferSubmission(for: transfer()) {}
        do { _ = try await factory.submitPreparedTransfer(prepared, info: transfer(), preTransportValidation: {}); XCTFail("Expected signer rejection") }
        catch { guard case PreparedExtrinsicTransportError.failedBeforeTransport = error else { return XCTFail("Unexpected \(error)") } }
        XCTAssertEqual(service.preparedSubmitCount, 0); XCTAssertThrowsError(try prepared.preparedExtrinsic.consumeForTransport())
    }
    func testPreparedLiquidityRejectsNonLifecycleSignerBeforeTransportAndDiscardsBytes() async throws {
        let (factory, service) = try make()
        let prepared = try await factory.prepareLiquiditySubmission(for: liquidity()) {}
        do { _ = try await factory.submitPreparedLiquidity(prepared, info: liquidity(), preTransportValidation: {}); XCTFail("Expected signer rejection") }
        catch { guard case PreparedExtrinsicTransportError.failedBeforeTransport = error else { return XCTFail("Unexpected \(error)") } }
        XCTAssertEqual(service.preparedSubmitCount, 0); XCTAssertThrowsError(try prepared.preparedExtrinsic.consumeForTransport())
    }
    func testCancelledPreparedTransferFailsBeforeTransportAndDiscardsBytes() async throws {
        let (factory, service) = try make()
        let prepared = try await factory.prepareTransferSubmission(for: transfer()) {}
        let task = Task { withUnsafeCurrentTask { $0?.cancel() }; return try await factory.submitPreparedTransfer(prepared, info: transfer(), preTransportValidation: {}) }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { guard case PreparedExtrinsicTransportError.failedBeforeTransport = error else { return XCTFail("Unexpected \(error)") } }
        XCTAssertEqual(service.preparedSubmitCount, 0); XCTAssertThrowsError(try prepared.preparedExtrinsic.consumeForTransport())
    }
    func testCancelledPreparedLiquidityFailsBeforeTransportAndDiscardsBytes() async throws {
        let (factory, service) = try make()
        let prepared = try await factory.prepareLiquiditySubmission(for: liquidity()) {}
        let task = Task { withUnsafeCurrentTask { $0?.cancel() }; return try await factory.submitPreparedLiquidity(prepared, info: liquidity(), preTransportValidation: {}) }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { guard case PreparedExtrinsicTransportError.failedBeforeTransport = error else { return XCTFail("Unexpected \(error)") } }
        XCTAssertEqual(service.preparedSubmitCount, 0); XCTAssertThrowsError(try prepared.preparedExtrinsic.consumeForTransport())
    }
    private func product(_ type: TransactionType, amount: Decimal = 1, changes: [String: String] = [:],
                         source: String? = nil, destination: String? = nil) -> TransferInfo {
        var context = [TransactionContextKeys.transactionType: type.rawValue,
                       TransactionContextKeys.rewardAsset: WalletAssetId.pswap.rawValue,
                       TransactionContextKeys.isFarm: "1", TransactionContextKeys.dex: "0",
                       TransactionContextKeys.desire: SwapVariant.desiredInput.rawValue,
                       TransactionContextKeys.estimatedAmount: "2", TransactionContextKeys.minMaxValue: "1.99",
                       TransactionContextKeys.slippage: "0.5", TransactionContextKeys.marketType: LiquiditySourceType.xyk.rawValue]
        context.merge(changes) { _, new in new }
        return TransferInfo(source: source ?? xor, destination: destination ?? val, amount: AmountDecimal(value: amount),
                            asset: source ?? xor, details: "", fees: [], context: context)
    }
    func testLegacyLiquidityProductUsesTheSameExactDepositCall() async throws {
        let (factory, service) = try make()
        let result = try await run(factory.transferOperation(liquidity(.liquidityAddNewPool)))
        XCTAssertEqual(result, Data(repeating: 10, count: 32)); XCTAssertEqual(service.submitCount, 1)
        let builder = try XCTUnwrap(service.builders.first)
        XCTAssertEqual(builder.atomicSelections, [true]); XCTAssertEqual(builder.calls.count, 3)
        let call = try builder.calls[2].map(to: RuntimeCall<DepositLiquidityCall>.self)
        XCTAssertEqual(call.args.desiredB, 2_345_678); XCTAssertEqual(call.args.minB, 2_333_949)
    }
    func testLegacyLiquidityRejectsMalformedContextWithoutSubmitting() async throws {
        let (factory, service) = try make()
        await expectFailure(.invalidContext) { try await run(factory.transferOperation(liquidity(changes: [TransactionContextKeys.slippage: "bad"]))) }
        XCTAssertEqual(service.submitCount, 0)
    }
    func testSwapProductPreservesPairSourceFilterAndSlippage() async throws {
        let (factory, service) = try make()
        let result = try await run(factory.transferOperation(product(.swap)))
        XCTAssertEqual(result, Data(repeating: 10, count: 32))
        let call = try service.builders[0].calls[0].map(to: RuntimeCall<SwapCall>.self)
        XCTAssertEqual(call.callName, "swap"); XCTAssertEqual(call.args.dexId, "0")
        XCTAssertEqual(call.args.inputAssetId.value, xor); XCTAssertEqual(call.args.outputAssetId.value, val)
        XCTAssertEqual(call.args.amount[.desiredInput]?.desired, BigUInt("1000000000000000000"))
        XCTAssertEqual(call.args.amount[.desiredInput]?.slip, BigUInt("1990000000000000000"))
        XCTAssertEqual(call.args.liquiditySourceType, [["XYKPool", nil]])
        XCTAssertEqual(call.args.filterMode.name, "AllowSelected")
    }
    func testSwapSmartRouteDoesNotAccidentallyKeepThePreviousSourceFilter() async throws {
        let (factory, service) = try make()
        _ = try await run(factory.transferOperation(product(.swap, changes: [TransactionContextKeys.marketType: ""])))
        let call = try service.builders[0].calls[0].map(to: RuntimeCall<SwapCall>.self)
        XCTAssertTrue(call.args.liquiditySourceType.isEmpty); XCTAssertEqual(call.args.filterMode.name, "Disabled")
    }
    func testSwapRejectsUnknownOrIdenticalAssetsBeforeSubmitting() async throws {
        for info in [product(.swap, source: "unknown"), product(.swap, destination: "unknown"), product(.swap, destination: xor)] {
            let (factory, service) = try make()
            await expectFailure(.invalidAsset) { try await run(factory.transferOperation(info)) }
            XCTAssertEqual(service.submitCount, 0)
        }
    }
    func testSwapRejectsInvalidMarketOrInconsistentSlippageBeforeSubmitting() async throws {
        for changes in [[TransactionContextKeys.marketType: "made-up"], [TransactionContextKeys.minMaxValue: "1.9"],
                        [TransactionContextKeys.desire: "bad"], [TransactionContextKeys.estimatedAmount: "2junk"]] {
            let (factory, service) = try make()
            await expectFailure(.invalidContext) { try await run(factory.transferOperation(product(.swap, changes: changes))) }
            XCTAssertEqual(service.submitCount, 0)
        }
    }
    private func decodeDemeter<T: Decodable>(_ json: JSON, as type: T.Type) throws -> T {
        // These calls declare explicit snake_case keys, so automatic key conversion
        // would change the keys before the call's decoder can match them.
        let data = try JSONEncoder.scaleCompatible().encode(SoraPassport.JsonContainer(value: json))
        return try JSONDecoder.scaleCompatible(snakeCase: false).decode(FactoryCallEnvelope<T>.self, from: data).value
    }
    func testDemeterClaimPreservesRewardAssetAndFarmFlag() async throws {
        for farm in ["0", "1"] {
            let (factory, service) = try make()
            let result = try await run(factory.transferOperation(product(.demeterClaimReward, changes: [TransactionContextKeys.isFarm: farm])))
            XCTAssertEqual(result, Data(repeating: 10, count: 32))
            let call = try decodeDemeter(service.builders[0].calls[0], as: RuntimeCall<DemeterFarmingClaimRewardCall>.self)
            XCTAssertEqual(call.callName, "get_rewards")
            XCTAssertEqual(call.args.baseAssetId.value, xor); XCTAssertEqual(call.args.targetAssetId.value, val)
            XCTAssertEqual(call.args.rewardAssetId.value, WalletAssetId.pswap.rawValue)
            XCTAssertEqual(call.args.isFarm, farm == "1")
        }
    }
    func testDemeterDepositPreservesFullEighteenDecimalTokenAmount() async throws {
        let (factory, service) = try make()
        _ = try await run(factory.transferOperation(product(.demeterDeposit, amount: Decimal(string: "1.234567890123456789")!)))
        let call = try decodeDemeter(service.builders[0].calls[0], as: RuntimeCall<DemeterFarmingDepositLiquidityCall>.self)
        XCTAssertEqual(call.callName, "deposit")
        XCTAssertEqual(call.args.amount, BigUInt("1234567890123456789")); XCTAssertTrue(call.args.isFarm)
        XCTAssertEqual(call.args.baseAssetId.value, xor); XCTAssertEqual(call.args.targetAssetId.value, val)
    }
    func testDemeterWithdrawalPreservesFullTokenAmountAndNonFarmFlag() async throws {
        let (factory, service) = try make()
        _ = try await run(factory.transferOperation(product(.demeterWithdraw, amount: Decimal(string: "0.000000000000000001")!,
            changes: [TransactionContextKeys.isFarm: "0"])))
        let call = try decodeDemeter(service.builders[0].calls[0], as: RuntimeCall<DemeterFarmingWithdrawLiquidityCall>.self)
        XCTAssertEqual(call.callName, "withdraw"); XCTAssertEqual(call.args.amount, 1); XCTAssertFalse(call.args.isFarm)
        XCTAssertEqual(call.args.rewardAssetId.value, WalletAssetId.pswap.rawValue)
    }
    func testDemeterAllOperationsRejectUnvalidatedContextBeforeService() async throws {
        for type in [TransactionType.demeterClaimReward, .demeterDeposit, .demeterWithdraw] {
            for changes in [[TransactionContextKeys.isFarm: "true"], [TransactionContextKeys.isFarm: "2"], [TransactionContextKeys.rewardAsset: ""]] {
                let (factory, service) = try make()
                await expectFailure(.invalidContext) { try await run(factory.transferOperation(product(type, changes: changes))) }
                XCTAssertEqual(service.submitCount, 0)
            }
        }
    }
    func testDemeterRejectsEmptyPairAssetsBeforeService() async throws {
        for type in [TransactionType.demeterClaimReward, .demeterDeposit, .demeterWithdraw] {
            for info in [product(type, source: ""), product(type, destination: "")] {
                let (factory, service) = try make()
                await expectFailure(.invalidContext) { try await run(factory.transferOperation(info)) }
                XCTAssertEqual(service.submitCount, 0)
            }
        }
    }
    func testDemeterDepositAndWithdrawalRejectNonpositiveOrSubAtomicAmounts() async throws {
        for type in [TransactionType.demeterDeposit, .demeterWithdraw] {
            for amount in [Decimal.zero, -1, Decimal(string: "0.0000000000000000001")!] {
                let (factory, service) = try make()
                await expectFailure(.invalidAmount) { try await run(factory.transferOperation(product(type, amount: amount))) }
                XCTAssertEqual(service.submitCount, 0)
            }
        }
    }
    func testLegacyProductFailurePropagatesWithoutConvertingItToSuccess() async throws {
        let (factory, service) = try make(); service.failure = FactoryBoundaryError.offline
        do { _ = try await run(factory.transferOperation(product(.demeterDeposit))); XCTFail("Expected offline error") }
        catch { XCTAssertTrue(error is FactoryBoundaryError) }
        XCTAssertEqual(service.submitCount, 1)
    }
    func testTransferMetadataRejectsUnknownAssetWithoutFeeOrStorageReads() async throws {
        let (factory, service) = try make()
        await expectFailure(.invalidAsset) {
            try await run(factory.transferMetadataOperation(TransferMetadataInfo(assetId: "unknown", sender: "sender", receiver: receiver)))
        }
        XCTAssertEqual(service.estimateCount, 0)
    }
    func testTransferMetadataRejectsInvalidReceiverBeforeFeeOrStorageReads() async throws {
        let (factory, service) = try make()
        await expectFailure(.invalidReceiver) {
            try await run(factory.transferMetadataOperation(TransferMetadataInfo(assetId: val, sender: "sender", receiver: "not-hex")))
        }
        XCTAssertEqual(service.estimateCount, 0)
    }
    private func transportFixture() throws -> (WalletNetworkOperationFactory, FactoryExtrinsics, AccountItem) {
        let key = Data(repeating: 3, count: 32)
        let account = AccountItem(address: try SS58AddressFactory().addressFromAccountId(data: key, type: Chain.sora.addressType()), cryptoType: .sr25519, networkType: Chain.sora.addressType(), username: "Public transport fixture", publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        let (factory, service) = try make(accountSigner: FactoryLifecycleSigner(account: account))
        SelectedWalletSettings.shared.commitInternalValue(account)
        return (factory, service, account)
    }
    private func preparedBytes() throws -> PreparedExtrinsicSubmission {
        let data = Data([1, 2, 3, 4]); return PreparedExtrinsicSubmission(data: data, hash: try data.blake2b32().toHex(includePrefix: true))
    }
    private func submit(_ factory: WalletNetworkOperationFactory, prepared: PreparedExtrinsicSubmission,
                        liquidity: Bool, validate: @escaping () throws -> Void = {}) async throws -> Data {
        if liquidity {
            return try await factory.submitPreparedLiquidity(PreparedLiquiditySubmission(fee: 1, rawFee: "7", preparedExtrinsic: prepared), info: self.liquidity(), preTransportValidation: validate)
        }
        return try await factory.submitPreparedTransfer(PreparedSora2TransferSubmission(fee: 1, rawFee: "7", preparedExtrinsic: prepared), info: transfer(), preTransportValidation: validate)
    }
    func testPreparedTransferForwardsExactSignedBytesAndReviewedFee() async throws {
        let (factory, service, _) = try transportFixture(), prepared = try preparedBytes(); var checks = 0
        let result = try await submit(factory, prepared: prepared, liquidity: false) { checks += 1 }
        XCTAssertEqual(result, try Data(hexStringSSF: prepared.hash)); XCTAssertEqual(service.transportedHex, ["0x01020304"])
        XCTAssertEqual(service.transportFees, ["7"]); XCTAssertEqual(service.transportWitnesses, [false]); XCTAssertEqual(checks, 1)
        XCTAssertThrowsError(try prepared.consumeForTransport())
    }
    func testPreparedLiquidityForwardsExactSignedBytesAndReviewedFee() async throws {
        let (factory, service, _) = try transportFixture(), prepared = try preparedBytes(); var checks = 0
        let result = try await submit(factory, prepared: prepared, liquidity: true) { checks += 1 }
        XCTAssertEqual(result, try Data(hexStringSSF: prepared.hash)); XCTAssertEqual(service.transportedHex, ["0x01020304"])
        XCTAssertEqual(service.transportFees, ["7"]); XCTAssertEqual(service.transportWitnesses, [false]); XCTAssertEqual(checks, 1)
    }
    func testPreparedSubmissionRequiresTheBoundWalletAtTransportTime() async throws {
        for liquidity in [false, true] {
            let (factory, service, _) = try transportFixture(); SelectedWalletSettings.shared.commitInternalValue(nil)
            do { _ = try await submit(factory, prepared: preparedBytes(), liquidity: liquidity); XCTFail("Missing wallet reached transport") }
            catch { XCTAssertTrue(error is PreparedExtrinsicTransportError) }
            XCTAssertTrue(service.transportedHex.isEmpty)
        }
    }
    func testPreparedSubmissionRejectsEveryChangedIdentityField() async throws {
        for liquidity in [false, true] {
            for changed in ["address", "key", "crypto", "network", "selected"] {
                let (factory, service, account) = try transportFixture()
                let selected = AccountItem(address: changed == "address" ? "another-wallet" : account.address,
                    cryptoType: changed == "crypto" ? .ed25519 : account.cryptoType,
                    networkType: changed == "network" ? 42 : account.networkType,
                    username: account.username, publicKeyData: changed == "key" ? Data(repeating: 4, count: 32) : account.publicKeyData,
                    settings: account.settings, order: account.order, isSelected: changed != "selected")
                SelectedWalletSettings.shared.commitInternalValue(selected)
                do { _ = try await submit(factory, prepared: preparedBytes(), liquidity: liquidity); XCTFail("Changed \(changed) reached transport") }
                catch { XCTAssertTrue(error is PreparedExtrinsicTransportError) }
                XCTAssertTrue(service.transportedHex.isEmpty)
            }
        }
    }
    func testWalletChangeInsideFinalValidationCannotEscapeTheIdentityCheck() async throws {
        for liquidity in [false, true] {
            let (factory, service, _) = try transportFixture()
            do { _ = try await submit(factory, prepared: preparedBytes(), liquidity: liquidity) { SelectedWalletSettings.shared.commitInternalValue(nil) }; XCTFail("Changed selection reached transport") }
            catch { XCTAssertTrue(error is PreparedExtrinsicTransportError) }
            XCTAssertTrue(service.transportedHex.isEmpty)
        }
    }
    func testFailedFinalReviewCannotConsumeSignedBytesForTransport() async throws {
        for liquidity in [false, true] {
            let (factory, service, _) = try transportFixture()
            do { _ = try await submit(factory, prepared: preparedBytes(), liquidity: liquidity) { throw FactoryBoundaryError.offline }; XCTFail("Failed review reached transport") }
            catch { XCTAssertTrue(error is PreparedExtrinsicTransportError) }
            XCTAssertTrue(service.transportedHex.isEmpty)
        }
    }
    func testPreparedSubmissionRequiresALifecycleBoundSigner() async throws {
        for liquidity in [false, true] {
            let (factory, service) = try make(), prepared = try preparedBytes()
            do { _ = try await submit(factory, prepared: prepared, liquidity: liquidity); XCTFail("Unbound signer admitted") }
            catch { XCTAssertTrue(error is PreparedExtrinsicTransportError) }
            XCTAssertEqual(service.preparedSubmitCount, 0); XCTAssertThrowsError(try prepared.consumeForTransport())
        }
    }
    func testReturnedHashMismatchIsReportedAsUnknownWithTheLocalHash() async throws {
        for liquidity in [false, true] {
            let (factory, service, _) = try transportFixture(), prepared = try preparedBytes()
            service.returnedTransportHash = "0x" + String(repeating: "ab", count: 32)
            do { _ = try await submit(factory, prepared: prepared, liquidity: liquidity); XCTFail("Mismatched hash accepted") }
            catch let error as PreparedExtrinsicTransportError {
                guard case .submissionUnknown = error else { return XCTFail("Wrong classification: \(error)") }
                XCTAssertEqual(error.submissionUnknownLocalHash, Sora2PendingSubmissionStore.normalizedHash(prepared.hash))
            }
            catch { XCTFail("Wrong classification: \(error)") }
            XCTAssertEqual(service.transportedHex.count, 1)
        }
    }
    func testEquivalentUppercaseHashIsAdmittedWithoutChangingItsBytes() async throws {
        for liquidity in [false, true] {
            let (factory, service, _) = try transportFixture(), prepared = try preparedBytes()
            service.returnedTransportHash = "0x" + prepared.hash.dropFirst(2).uppercased()
            let result = try await submit(factory, prepared: prepared, liquidity: liquidity)
            XCTAssertEqual(result, try Data(hexStringSSF: prepared.hash))
        }
    }
    func testTransportFailureDoesNotBecomeASuccessfulHash() async throws {
        for liquidity in [false, true] {
            let (factory, service, _) = try transportFixture()
            service.transportFailure = PreparedExtrinsicTransportError.submissionUnknown(localHash: "0x" + String(repeating: "ab", count: 32), error: FactoryBoundaryError.offline)
            do { _ = try await submit(factory, prepared: preparedBytes(), liquidity: liquidity); XCTFail("Transport failure ignored") }
            catch { XCTAssertTrue(error is PreparedExtrinsicTransportError) }
        }
    }
    func testCancellationBeforeSubmissionDiscardsPreparedBytesWithoutTransport() async throws {
        for liquidity in [false, true] {
            let (factory, service, _) = try transportFixture(), prepared = try preparedBytes()
            let task = Task { @MainActor in
                withUnsafeCurrentTask { $0?.cancel() }
                return try await self.submit(factory, prepared: prepared, liquidity: liquidity)
            }
            do { _ = try await task.value; XCTFail("Cancelled submission succeeded") }
            catch { XCTAssertTrue(error is PreparedExtrinsicTransportError) }
            XCTAssertEqual(service.preparedSubmitCount, 0); XCTAssertThrowsError(try prepared.consumeForTransport())
        }
    }
}

private enum FactoryBoundaryError: Error { case offline, unexpected }
private final class FactoryCall: CancellableCall {
    var cancelled = false
    func cancel() { cancelled = true }
}
private final class FactoryExtrinsics: ExtrinsicServiceProtocol {
    var rawFee = "7"
    var failure: Error?
    var builders: [FactoryBuilder] = []
    var estimateCount = 0
    var prepareCount = 0
    var submitCount = 0
    var preparedSubmitCount = 0
    var transportFees: [String] = [], transportedHex: [String] = [], transportWitnesses: [Bool] = []
    var returnedTransportHash: String?, transportFailure: Error?
    var cancelAfterPrepare = false
    var prepared: PreparedExtrinsicSubmission?
    let call = FactoryCall()
    private func record(_ closure: ExtrinsicBuilderClosure) throws {
        let builder = FactoryBuilder(); _ = try closure(builder); builders.append(builder)
        if let failure { throw failure }
    }
    func estimateFee(_ closure: @escaping ExtrinsicBuilderClosure, runningIn queue: DispatchQueue, completion: @escaping EstimateFeeClosure) {
        estimateCount += 1
        do { try record(closure); completion(.success(rawFee)) } catch { completion(.failure(error)) }
    }
    func prepareAndEstimateFee(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
                               preSigningValidation: @escaping () throws -> Void, runningIn queue: DispatchQueue,
                               completion: @escaping (Result<PreparedExtrinsicFeeQualification, Error>) -> Void) -> CancellableCall {
        prepareCount += 1
        do {
            try preSigningValidation(); try record(closure)
            let bytes = Data([1, 2, 3, 4])
            let result = PreparedExtrinsicSubmission(data: bytes, hash: try bytes.blake2b32().toHex(includePrefix: true))
            prepared = result
            if cancelAfterPrepare { withUnsafeCurrentTask { $0?.cancel() } }
            completion(.success(PreparedExtrinsicFeeQualification(prepared: result, rawFee: rawFee)))
        } catch { completion(.failure(error)) }
        return call
    }
    func prepareAndEstimateFee(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
        lifecycleLease: WalletLifecycleLease?, runtimeValidation: ((RuntimeCoderFactoryProtocol) throws -> Void)?,
        finalizedHeadValidation: ((String) throws -> Void)?, preSigningValidation: @escaping () throws -> Void,
        runningIn queue: DispatchQueue, completion: @escaping (Result<PreparedExtrinsicFeeQualification, Error>) -> Void) -> CancellableCall {
        XCTFail("Unexpected lifecycle preparation"); completion(.failure(FactoryBoundaryError.unexpected)); return call
    }
    func submit(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol, runningIn queue: DispatchQueue,
                completion: @escaping ExtrinsicSubmitClosure) {
        submitCount += 1
        do { try record(closure); completion(.success("0x" + String(repeating: "0a", count: 32)), "0x" + String(repeating: "0a", count: 32), nil) }
        catch { completion(.failure(error), nil, nil) }
    }
    func submit(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol, lifecycleLease: WalletLifecycleLease?,
                runningIn queue: DispatchQueue, completion: @escaping ExtrinsicSubmitClosure) {
        XCTFail("Unexpected lifecycle submission"); completion(.failure(FactoryBoundaryError.unexpected), nil, nil)
    }
    func prepare(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol, runningIn queue: DispatchQueue,
                 completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void) {
        XCTFail("Unexpected unqualified preparation"); completion(.failure(FactoryBoundaryError.unexpected))
    }
    func prepare(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol, lifecycleLease: WalletLifecycleLease?,
        runtimeValidation: ((RuntimeCoderFactoryProtocol) throws -> Void)?, preSigningValidation: (() throws -> Void)?,
        runningIn queue: DispatchQueue, completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void) {
        XCTFail("Unexpected lifecycle preparation"); completion(.failure(FactoryBoundaryError.unexpected))
    }
    func submitPrepared(_ prepared: PreparedExtrinsicSubmission, retainingTransportWitness: Bool, expectedRawFee: String,
        preTransportValidation: @escaping () throws -> Void, runningIn queue: DispatchQueue,
        completion: @escaping (Result<String, Error>) -> Void) -> CancellableCall {
        preparedSubmitCount += 1; transportFees.append(expectedRawFee); transportWitnesses.append(retainingTransportWitness)
        do {
            try preTransportValidation()
            let payload = try prepared.consumeForTransport()
            transportedHex.append(try payload.consumeHexForTransport())
            if let transportFailure { completion(.failure(transportFailure)) }
            else { completion(.success(returnedTransportHash ?? prepared.hash)) }
        } catch { completion(.failure(PreparedExtrinsicTransportError.failedBeforeTransport(error))) }
        return call
    }
}
private final class FactoryBuilder: SoraPassport.ExtrinsicBuilderProtocol {
    var calls: [JSON] = []
    var atomicSelections: [Bool] = []
    func with<A: Codable>(address: A) throws -> Self { XCTFail("Unexpected address binding"); return self }
    func with(nonce: UInt32) -> Self { XCTFail("Unexpected nonce"); return self }
    func with(era: Era, blockHash: String) -> Self { XCTFail("Unexpected era"); return self }
    func with(tip: BigUInt) -> Self { XCTFail("Unexpected tip"); return self }
    func with(shouldUseAtomicBatch: Bool) -> Self { atomicSelections.append(shouldUseAtomicBatch); return self }
    func adding<T: RuntimeCallable>(call: T) throws -> Self { let encoded = try JSONEncoder.scaleCompatible().encode(SoraPassport.EncodingContainer(value: call)); calls.append(try JSONDecoder.scaleCompatible(snakeCase: false).decode(SoraPassport.JsonContainer.self, from: encoded).value); return self }
    func adding(rawCall: Data) throws -> Self { XCTFail("Unexpected raw call"); throw FactoryBoundaryError.unexpected }
    func signing(by signer: (Data) throws -> Data, of type: SoraPassport.CryptoType, using encoder: DynamicScaleEncoding,
                 metadata: RuntimeMetadata) throws -> Self { XCTFail("Unexpected signing"); throw FactoryBoundaryError.unexpected }
    func buildExtrinsic(metadata: RuntimeMetadata) throws -> Extrinsic { XCTFail("Unexpected extrinsic build"); throw FactoryBoundaryError.unexpected }
    func build(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws -> Data { throw FactoryBoundaryError.unexpected }
    func buildSignature(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws -> Data { throw FactoryBoundaryError.unexpected }
}
private final class FactoryNoSigner: SigningWrapperProtocol {
    func sign(_ originalData: Data) throws -> IRSignatureProtocol { XCTFail("No signing is permitted in these factory tests"); throw FactoryBoundaryError.unexpected }
}
private final class FactoryNoRuntime: SoraPassport.RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { XCTFail("Unexpected runtime read"); throw FactoryBoundaryError.unexpected }
    }
}
private final class FactoryNoEngine: JSONRPCEngine {
    var url: URL?; var pendingEngineRequests: [JSONRPCRequest] { [] }
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 { XCTFail("Unexpected network request"); throw FactoryBoundaryError.unexpected }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 { XCTFail("Unexpected subscription"); throw FactoryBoundaryError.unexpected }
    func cancelForIdentifier(_ identifier: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_ subscription: JSONRPCSubscribing) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ identifier: UInt16) throws {}
}
private struct FactoryEmptyStorage: DataProviderRepositoryProtocol {
    typealias Model = ChainStorageItem
    func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]> { ClosureOperation { [] } }
    func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions) -> BaseOperation<[Model]> { ClosureOperation { [] } }
    func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions) -> BaseOperation<Model?> { ClosureOperation { nil } }
    func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[Model]> { ClosureOperation { [] } }
    func saveOperation(_ updates: @escaping () throws -> [Model], _ deletes: @escaping () throws -> [String]) -> BaseOperation<Void> { ClosureOperation { throw FactoryBoundaryError.unexpected } }
    func saveBatchOperation(_ updates: @escaping () throws -> [Model], _ deletes: @escaping () throws -> [String]) -> BaseOperation<Void> { saveOperation(updates, deletes) }
    func replaceOperation(_ models: @escaping () throws -> [Model]) -> BaseOperation<Void> { ClosureOperation { throw FactoryBoundaryError.unexpected } }
    func deleteAllOperation() -> BaseOperation<Void> { ClosureOperation { throw FactoryBoundaryError.unexpected } }
    func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { 0 } }
}

private struct FactoryCallEnvelope<T: Decodable>: Decodable { let value: T }

private final class FactoryLifecycleSigner: LifecycleSigningWrapperProtocol {
    let signingAccount: AccountItem
    init(account: AccountItem) { signingAccount = account }
    func sign(_ originalData: Data) throws -> IRSignatureProtocol { XCTFail("No real signing in factory transport tests"); throw FactoryBoundaryError.unexpected }
    func sign(_ originalData: Data, lifecycleLease: WalletLifecycleLease) throws -> IRSignatureProtocol { XCTFail("No real signing in factory transport tests"); throw FactoryBoundaryError.unexpected }
}
