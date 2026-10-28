// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import IrohaCrypto
import SoraFoundation
import SSFUtils
import XCTest
@testable import SoraPassport

final class LocalHistoryProjectionTests: XCTestCase {
    private let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue
    private let addressFactory = SS58AddressFactory()
    private let rawPeer = Data(repeating: 2, count: 32)
    private var selfAddress: String { get throws { try addressFactory.address(fromAccountId: Data(repeating: 1, count: 32), type: SNAddressType(chain: .sora)) } }
    private var peerAddress: String { get throws { try addressFactory.address(fromAccountId: rawPeer, type: SNAddressType(chain: .sora)) } }
    private let one = BigUInt(10).power(18)
    private var asset: WalletAsset { WalletAsset(identifier: xor, name: LocalizableResource { _ in "SORA" }, symbol: "XOR", precision: 18) }
    private func call<T: Codable>(_ path: CallCodingPath, _ args: T) throws -> Data { try JSONEncoder.scaleCompatible().encode(RuntimeCall(moduleName: path.moduleName, callName: path.callName, args: args)) }
    private func item(_ path: CallCodingPath, call: Data, status: TransactionHistoryItem.Status = .pending, sender: String? = nil, receiver: String? = nil, fee: String = "1000000000000000") throws -> TransactionHistoryItem {
        TransactionHistoryItem(sender: try sender ?? selfAddress, receiver: try receiver ?? peerAddress, status: status, txHash: "0x012345", timestamp: 1700000000, fee: fee, blockNumber: 10, txIndex: 3, callPath: path, call: call)
    }
    private func project(_ item: TransactionHistoryItem) throws -> AssetTransactionData { AssetTransactionData.createTransaction(from: item, address: try selfAddress, networkType: SNAddressType(chain: .sora), asset: asset, addressFactory: addressFactory) }
    private func transfer(_ path: CallCodingPath = .transfer, status: TransactionHistoryItem.Status = .pending, fee: String = "1000000000000000") throws -> AssetTransactionData {
        try project(item(path, call: call(path, SoraTransferCall(receiver: rawPeer, amount: one * 3 / 2, assetId: AssetId(wrappedValue: val))), status: status, fee: fee))
    }
    private func swap(_ variant: SwapVariant = .desiredInput, market: LiquiditySourceType = .xyk) throws -> AssetTransactionData {
        let path = CallCodingPath.swap
        let args = SwapCall(dexId: "0", inputAssetId: AssetId(wrappedValue: xor), outputAssetId: AssetId(wrappedValue: val), amount: [variant: SwapAmount(type: variant, desired: one * 2, slip: one * 7)], liquiditySourceType: market.code, filterMode: FilterModeType(wrappedName: "AllowSelected", wrappedValue: 2))
        return try project(item(path, call: call(path, args)))
    }
    private func referral(_ path: CallCodingPath = .bondReferralBalance, status: TransactionHistoryItem.Status = .pending, fee: String = "1000000000000000") throws -> AssetTransactionData { try project(item(path, call: call(path, ReferralBalanceCall(balance: one * 4)), status: status, fee: fee)) }
    private func deposit() -> DepositLiquidityCall { DepositLiquidityCall(dexId: "0", assetA: AssetId(wrappedValue: xor), assetB: AssetId(wrappedValue: val), desiredA: one * 2, desiredB: one * 7, minA: one, minB: one * 6) }

    func testOutgoingTransferPreservesExactAmountPeerAndToken() throws { let value = try transfer(); XCTAssertEqual(value.type, TransactionType.outgoing.rawValue); XCTAssertEqual(value.assetId, val); XCTAssertEqual(value.amount.decimalValue, Decimal(string: "1.5")); XCTAssertEqual(value.peerId, rawPeer.toHex()); XCTAssertEqual(value.peerName, try peerAddress); XCTAssertEqual(value.context?[TransactionContextKeys.extrinsicHash], "0x012345") }
    func testIncomingTransferResolvesTheSenderAsItsPeer() throws { let args = SoraTransferCall(receiver: Data(repeating: 1, count: 32), amount: one, assetId: AssetId(wrappedValue: val)); let value = try project(item(.transfer, call: call(.transfer, args), sender: peerAddress, receiver: selfAddress)); XCTAssertEqual(value.type, TransactionType.incoming.rawValue); XCTAssertEqual(value.peerId, rawPeer.toHex()) }
    func testTransferKeepAliveUsesTheSameTransferProjection() throws { XCTAssertEqual(try transfer(.transferKeepAlive).amount.decimalValue, Decimal(string: "1.5")); XCTAssertEqual(try transfer(.transferKeepAlive).assetId, val) }
    func testTransferPreservesPendingSucceededAndFailedOutcomes() throws { for (source, expected) in [(TransactionHistoryItem.Status.pending, AssetTransactionStatus.pending), (.success, .commited), (.failed, .rejected)] { XCTAssertEqual(try transfer(status: source).status, expected) } }
    func testTransferKeepsHashTimestampAndXorFee() throws { let value = try transfer(); XCTAssertEqual(value.transactionId, "0x012345"); XCTAssertEqual(value.timestamp, 1700000000); XCTAssertEqual(value.fees.first?.amount.decimalValue, Decimal(string: "0.001")); XCTAssertEqual(value.fees.first?.assetId, xor) }
    func testTransferAcceptsHistoricalDecimalFeesWithoutRescaling() throws { XCTAssertEqual(try transfer(fee: "0.125").fees.first?.amount.decimalValue, Decimal(string: "0.125")) }
    func testTransferDoesNotAcceptAPartiallyNumericFee() throws { XCTAssertEqual(try transfer(fee: "2trailing").fees.first?.amount.decimalValue, 0) }
    func testTransferRejectsNegativeFees() throws { XCTAssertEqual(try transfer(fee: "-2").fees.first?.amount.decimalValue, 0) }
    func testMalformedTransferDoesNotInventAnAmountOrToken() throws { let value = try project(item(.transfer, call: Data("invalid".utf8))); XCTAssertEqual(value.amount.decimalValue, 0); XCTAssertEqual(value.assetId, xor); XCTAssertEqual(value.status, .pending) }
    func testUnparseablePeerAddressIsPreservedForDisplay() throws { let value = try project(item(.transfer, call: Data(), receiver: "unrecognized-receiver")); XCTAssertEqual(value.peerId, "unrecognized-receiver"); XCTAssertEqual(value.peerName, "unrecognized-receiver") }
    func testDesiredInputSwapShowsInputAndMinimumOutputWithoutReversingTokens() throws { let value = try swap(); XCTAssertEqual(value.peerId, xor); XCTAssertEqual(value.assetId, val); XCTAssertEqual(Decimal(string: value.details), 2); XCTAssertEqual(value.amount.decimalValue, 7) }
    func testDesiredOutputSwapShowsMaximumInputAndDesiredOutput() throws { let value = try swap(.desiredOutput); XCTAssertEqual(Decimal(string: value.details), 7); XCTAssertEqual(value.amount.decimalValue, 2) }
    func testSwapRetainsItsSelectedXykMarket() throws { XCTAssertEqual(try swap(market: .xyk).peerName, LiquiditySourceType.xyk.rawValue) }
    func testSwapRetainsItsSelectedTbcMarket() throws { XCTAssertEqual(try swap(market: .tbc).peerName, LiquiditySourceType.tbc.rawValue) }
    func testSmartSwapRemainsUnrestricted() throws { XCTAssertEqual(try swap(market: .smart).peerName, LiquiditySourceType.smart.rawValue) }
    func testDirectLiquidityDepositKeepsBothAmountsAndBothAssetIds() throws { let value = try project(item(.depositLiquidity, call: call(.depositLiquidity, deposit()))); XCTAssertEqual(value.type, TransactionType.liquidityAdd.rawValue); XCTAssertEqual(value.peerId, xor); XCTAssertEqual(value.assetId, val); XCTAssertEqual(Decimal(string: value.details), 2); XCTAssertEqual(value.amount.decimalValue, 7) }
    func testUtilityBatchFindsTheDepositAmongOtherCalls() throws { let encoded = try JSONSerialization.jsonObject(with: call(.depositLiquidity, deposit())); let raw: [Any] = ["Utility", ["batch", ["calls": [["System", ["remark", ["remark": "0x"]]], encoded]]]]; let value = try project(item(.utilityBatch, call: JSONSerialization.data(withJSONObject: raw))); XCTAssertEqual(value.type, TransactionType.liquidityAdd.rawValue); XCTAssertEqual(value.amount.decimalValue, 7) }
    func testAtomicBatchFindsTheDepositWithoutTreatingSetupAsAnAmount() throws { let encoded = try JSONSerialization.jsonObject(with: call(.depositLiquidity, deposit())); let raw: [Any] = ["Utility", ["batch_all", ["calls": [encoded]]]]; let value = try project(item(.utilityBatchAll, call: JSONSerialization.data(withJSONObject: raw))); XCTAssertEqual(value.type, TransactionType.liquidityAdd.rawValue); XCTAssertEqual(Decimal(string: value.details), 2) }
    func testUnrelatedBatchRemainsAnExtrinsic() throws { let raw: [Any] = ["Utility", ["batch", ["calls": [["System", ["remark", ["remark": "0x"]]]]]]]; let value = try project(item(.utilityBatch, call: JSONSerialization.data(withJSONObject: raw))); XCTAssertEqual(value.type, TransactionType.extrinsic.rawValue); XCTAssertEqual(value.peerName, "Utility batch") }
    func testDepositDetectionRequiresTheActualCallPath() throws { let wrong = try item(.depositLiquidity, call: call(.swap, deposit())); XCTAssertNil(AssetTransactionData.depositLiquidityCall(from: wrong)) }
    func testWithdrawalShowsItsMinimumTokenAmountsNotTheBurnedLpQuantity() throws { let args = WithdrawLiquidityCall(dexId: "0", assetA: AssetId(wrappedValue: xor), assetB: AssetId(wrappedValue: val), assetDesired: one * 99, minA: one * 2, minB: one * 7); let value = try project(item(.withdrawLiquidity, call: call(.withdrawLiquidity, args))); XCTAssertEqual(value.type, TransactionType.liquidityRemoval.rawValue); XCTAssertEqual(Decimal(string: value.details), 2); XCTAssertEqual(value.amount.decimalValue, 7) }
    func testPendingReferralDoesNotPretendItWasCommitted() throws { XCTAssertEqual(try referral().status, .pending) }
    func testFailedReferralRetainsItsFailedOutcome() throws { XCTAssertEqual(try referral(status: .failed).status, .rejected) }
    func testSuccessfulReferralCarriesTheWholeAmountAndDirection() throws { let value = try referral(status: .success); XCTAssertEqual(value.status, .commited); XCTAssertEqual(value.amount.decimalValue, 4); XCTAssertEqual(value.context?[TransactionContextKeys.referralTransactionType], ReferralMethodType.bond.rawValue) }
    func testReferralDirectionMatchesDecodedCallPathsToo() throws { let path = CallCodingPath(moduleName: "Referrals", callName: "unreserve"); let value = try referral(path); XCTAssertEqual(value.context?[TransactionContextKeys.referralTransactionType], ReferralMethodType.unbond.rawValue) }
    func testUnbondReferralCarriesItsWithdrawnAmount() throws { let value = try referral(.unbondReferralBalance); XCTAssertEqual(value.amount.decimalValue, 4); XCTAssertEqual(value.context?[TransactionContextKeys.referralTransactionType], ReferralMethodType.unbond.rawValue) }
    func testReferralAcceptsHistoricalDecimalFeeFormatConsistently() throws { XCTAssertEqual(try referral(fee: "0.125").fees.first?.amount.decimalValue, Decimal(string: "0.125")) }
    func testSetReferrerPreservesTheSelectedReferrerAddress() throws { let value = try project(item(.setReferral, call: call(.setReferral, SetReferrerCall(referrer: rawPeer)))); XCTAssertEqual(value.context?[TransactionContextKeys.referrer], try peerAddress); XCTAssertEqual(value.context?[TransactionContextKeys.sender], try selfAddress); XCTAssertEqual(value.amount.decimalValue, 0) }
    func testMigrationPreservesTheIrohaAccountAndOutcomeWithoutFees() throws { let args = MigrateCall(irohaAddress: "fixture@sora", irohaPublicKey: "fixture-key", irohaSignature: "fixture-signature"); let value = try project(item(.migration, call: call(.migration, args), status: .failed)); XCTAssertEqual(value.type, TransactionType.migration.rawValue); XCTAssertEqual(value.peerName, "fixture@sora"); XCTAssertEqual(value.status, .rejected); XCTAssertTrue(value.fees.isEmpty) }
    func testOtherExtrinsicKeepsItsCallNameHashFeeAndOutcome() throws { let path = CallCodingPath(moduleName: "System", callName: "remark"); let value = try project(item(path, call: Data(), status: .failed)); XCTAssertEqual(value.type, TransactionType.extrinsic.rawValue); XCTAssertEqual(value.peerFirstName, "System"); XCTAssertEqual(value.peerLastName, "remark"); XCTAssertEqual(value.amount.decimalValue, Decimal(string: "0.001")); XCTAssertEqual(value.status, .rejected); XCTAssertEqual(value.context?[TransactionContextKeys.extrinsicHash], "0x012345") }
    func testDesiredOutputAmountCodecDoesNotSwapItsNamedFields() throws { let original = SwapAmount(type: .desiredOutput, desired: 2, slip: 7); let decoded = try JSONDecoder().decode(SwapAmount.self, from: JSONEncoder().encode(original)); XCTAssertEqual(decoded.type, .desiredOutput); XCTAssertEqual(decoded.desired, 2); XCTAssertEqual(decoded.slip, 7) }
    func testDesiredInputAmountCodecKeepsItsNamedFields() throws { let original = SwapAmount(type: .desiredInput, desired: 2, slip: 7); let decoded = try JSONDecoder().decode(SwapAmount.self, from: JSONEncoder().encode(original)); XCTAssertEqual(decoded.type, .desiredInput); XCTAssertEqual(decoded.desired, 2); XCTAssertEqual(decoded.slip, 7) }
    func testSwapAmountRejectsMalformedIntegerFieldsInsteadOfZeroingThem() throws { for json in [#"{"desiredAmountIn":"oops","minAmountOut":"2"}"#, #"{"desiredAmountOut":"2","maxAmountIn":"-1"}"#, #"{"desiredAmountIn":"1.5","minAmountOut":"2"}"#] { XCTAssertThrowsError(try JSONDecoder().decode(SwapAmount.self, from: Data(json.utf8))) } }
}
