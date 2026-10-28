// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
import IrohaCrypto
import SoraFoundation
import sorawallet
import XCTest
@testable import SoraPassport

final class WalletHistoryConversionTests: XCTestCase {
    private let address = "cnRWUatULzf8AVfKVexXMKJx9bT9UeTEM4wmWG7B7g1cxVjXy"
    private let peer = "other-account"
    private var asset: WalletAsset {
        WalletAsset(identifier: "XOR", name: LocalizableResource { _ in "SORA" }, symbol: "XOR", precision: 18)
    }
    private var transfer: [String: String] {
        ["from": address, "to": peer, "amount": "1.25", "assetId": "VAL"]
    }
    private var swap: [String: String] {
        ["baseAssetId": "XOR", "targetAssetId": "VAL", "baseAssetAmount": "2.5",
         "targetAssetAmount": "5.25", "liquidityProviderFee": "0.01", "selectedMarket": "XYK"]
    }
    private func subquery(_ fields: [String: Any], fee: String = "7", success: Bool = true) throws -> SubqueryHistoryElement {
        let data = try JSONSerialization.data(withJSONObject: ["id": "transaction-1", "timestamp": "1234",
            "blockHash": "block-1", "address": address, "networkFee": fee, "data": fields,
            "execution": ["success": success]])
        return try JSONDecoder().decode(SubqueryHistoryElement.self, from: data)
    }
    private func sdk(_ fields: [String: String], fee: String = "7", success: Bool = true,
                     method: String = "transfer", nested: [TxHistoryItemNested]? = nil) -> TxHistoryItem {
        TxHistoryItem(id: "transaction-1", blockHash: "block-1", module: "assets", method: method,
            timestamp: "1234", networkFee: fee, success: success,
            data: fields.map { TxHistoryItemParam(paramName: $0.key, paramValue: $0.value) }, nestedData: nested)
    }
    private func convert(_ item: WalletRemoteHistoryItemProtocol, account: String? = nil) -> AssetTransactionData? {
        item.createTransactionForAddress(account ?? address, networkType: 69, asset: asset, addressFactory: SS58AddressFactory())
    }

    func testBothTransferAdaptersPreserveDirectionAmountFeeAndIdentifier() throws {
        let inputs: [WalletRemoteHistoryItemProtocol] = [try subquery(transfer), sdk(transfer)]
        for input in inputs {
            let outgoing = try XCTUnwrap(convert(input))
            XCTAssertEqual(outgoing.transactionId, "transaction-1")
            XCTAssertEqual(outgoing.timestamp, 1234)
            XCTAssertEqual(outgoing.assetId, "VAL")
            XCTAssertEqual(outgoing.amount.decimalValue, Decimal(string: "1.25"))
            XCTAssertEqual(outgoing.fees.first?.amount.decimalValue, 7)
            XCTAssertEqual(outgoing.type, TransactionType.outgoing.rawValue)
            XCTAssertEqual(outgoing.peerName, peer)
            XCTAssertEqual(outgoing.status, .commited)
            XCTAssertEqual(outgoing.context?[TransactionContextKeys.extrinsicHash], "transaction-1")
            let incoming = try XCTUnwrap(convert(input, account: peer))
            XCTAssertEqual(incoming.type, TransactionType.incoming.rawValue)
            XCTAssertEqual(incoming.peerName, address)
            XCTAssertFalse(incoming.peerId.isEmpty)
            XCTAssertEqual(input.itemBlockNumber, 0)
            XCTAssertEqual(input.itemExtrinsicIndex, 0)
            XCTAssertEqual(input.extrinsicHash, "transaction-1")
        }
    }

    func testBothTransferAdaptersKeepFailureStatus() throws {
        for input in [try subquery(transfer, success: false) as WalletRemoteHistoryItemProtocol,
                      sdk(transfer, success: false)] {
            XCTAssertEqual(convert(input)?.status, .rejected)
        }
    }

    func testBothSwapAdaptersPreserveBothAssetsAndProviderFee() throws {
        for input in [try subquery(swap) as WalletRemoteHistoryItemProtocol, sdk(swap)] {
            let result = try XCTUnwrap(convert(input))
            XCTAssertEqual(result.type, TransactionType.swap.rawValue)
            XCTAssertEqual(result.assetId, "VAL")
            XCTAssertEqual(result.peerId, "XOR")
            XCTAssertEqual(result.peerName, "XYK")
            XCTAssertEqual(result.details, "2.5")
            XCTAssertEqual(result.amount.decimalValue, Decimal(string: "5.25"))
            XCTAssertEqual(result.fees.map(\.amount.decimalValue), [7, Decimal(string: "0.01")!])
            XCTAssertEqual(result.fees.last?.context?["type"], TransactionType.swap.rawValue)
        }
    }

    func testBothLiquidityAdaptersPreserveDepositAndRemovalSides() throws {
        for type in ["Deposit", "Removal"] {
            let fields = ["baseAssetId": "XOR", "targetAssetId": "VAL", "baseAssetAmount": "2.5",
                          "targetAssetAmount": "5.25", "type": type]
            for input in [try subquery(fields) as WalletRemoteHistoryItemProtocol, sdk(fields)] {
                let result = try XCTUnwrap(convert(input))
                XCTAssertEqual(result.assetId, "VAL")
                XCTAssertEqual(result.peerId, "XOR")
                XCTAssertEqual(result.details, "2.5")
                XCTAssertEqual(result.amount.decimalValue, Decimal(string: "5.25"))
                XCTAssertEqual(result.type, type == "Deposit" ? TransactionType.liquidityAdd.rawValue : TransactionType.liquidityRemoval.rawValue)
            }
        }
    }

    func testSubqueryRewardsAndSlashesConvertAtomicAmountsAndEra() throws {
        for reward in [true, false] {
            let input = try subquery(["amount": "2500000000000000000", "isReward": reward, "era": 3, "validator": "validator"])
            let result = try XCTUnwrap(convert(input))
            XCTAssertEqual(result.amount.decimalValue, Decimal(string: "2.5"))
            XCTAssertEqual(result.type, reward ? TransactionType.reward.rawValue : TransactionType.slash.rawValue)
            XCTAssertEqual(result.peerId, "validator")
            XCTAssertEqual(result.context?[TransactionContextKeys.era], "3")
            XCTAssertTrue(result.fees.isEmpty)
        }
        let result = try XCTUnwrap(convert(try subquery(["amount": "0", "isReward": true])))
        XCTAssertEqual(result.peerId, "")
        XCTAssertNil(result.context)
    }

    func testSubqueryExtrinsicPreservesRuntimeFailureAndAtomicFee() throws {
        for success in [true, false] {
            let input = try subquery(["hash": "extrinsic-hash", "module": "balances", "call": "transfer",
                                      "fee": "500000000000000000", "success": success])
            let result = try XCTUnwrap(convert(input))
            XCTAssertEqual(result.type, TransactionType.extrinsic.rawValue)
            XCTAssertEqual(result.amount.decimalValue, Decimal(string: "0.5"))
            XCTAssertEqual(result.status, success ? .commited : .rejected)
            XCTAssertEqual(result.peerName, "balances transfer")
            XCTAssertEqual(result.context?[TransactionContextKeys.extrinsicHash], "extrinsic-hash")
        }
    }

    func testSDKReferralDirectionAndMissingAmountRemainDistinctFromTransfer() throws {
        let fields = ["from": address, "to": peer]
        let result = try XCTUnwrap(convert(sdk(fields, method: "setReferrer")))
        XCTAssertEqual(result.type, TransactionType.referral.rawValue)
        XCTAssertEqual(result.amount.decimalValue, 0)
        XCTAssertEqual(result.context?[TransactionContextKeys.referralTransactionType], ReferralMethodType.setReferrer.rawValue)
        let received = try XCTUnwrap(convert(sdk(fields, method: "setReferrer"), account: peer))
        XCTAssertEqual(received.context?[TransactionContextKeys.referralTransactionType], ReferralMethodType.setReferral.rawValue)
        XCTAssertEqual(received.context?[TransactionContextKeys.blockHash], "block-1")
        for method in ["reserve", "unreserve"] {
            let item = sdk(fields.merging(["amount": "3.5"]) { _, new in new }, method: method)
            let converted = try XCTUnwrap(convert(item))
            XCTAssertEqual(converted.amount.decimalValue, Decimal(string: "3.5"))
            XCTAssertEqual(converted.context?[TransactionContextKeys.referralTransactionType], method)
        }
    }

    func testSDKCreatePoolReadsNestedDepositAmounts() throws {
        let nested = TxHistoryItemNested(module: "poolXYK", method: "depositLiquidity", hash: "nested-hash",
            data: ["inputAssetA": "XOR", "inputAssetB": "VAL", "inputADesired": "3", "inputBDesired": "6"].map {
                TxHistoryItemParam(paramName: $0.key, paramValue: $0.value)
            })
        let result = try XCTUnwrap(convert(sdk([:], nested: [nested])))
        XCTAssertEqual(result.assetId, "XOR")
        XCTAssertEqual(result.peerId, "VAL")
        XCTAssertEqual(result.amount.decimalValue, 3)
        XCTAssertEqual(result.details, "6")
        XCTAssertEqual(result.type, "Deposit")
    }

    func testUnrecognizedHistoryPayloadHasNoTransaction() throws {
        XCTAssertNil(convert(try subquery(["unknown": "value"])))
        XCTAssertNil(convert(sdk(["unknown": "value"])))
    }

    func testBothTransferAdaptersRejectMalformedAndLossyAmounts() throws {
        for raw in ["", "1garbage", "1e2", "-1", "NaN", "1.2.3", "1\n", String(repeating: "9", count: 45)] {
            let fields = transfer.merging(["amount": raw]) { _, new in new }
            XCTAssertNil(convert(try subquery(fields)), raw)
            XCTAssertNil(convert(sdk(fields)), raw)
        }
    }

    func testBothAdaptersRejectInvalidNetworkFeesRatherThanInventingZero() throws {
        for raw in ["", "7garbage", "-1", "NaN", "1\n", String(repeating: "9", count: 45)] {
            XCTAssertNil(convert(try subquery(transfer, fee: raw)), raw)
            XCTAssertNil(convert(sdk(transfer, fee: raw)), raw)
        }
    }

    func testBothSwapAdaptersValidateBothAmountsAndProviderFee() throws {
        for key in ["baseAssetAmount", "targetAssetAmount", "liquidityProviderFee"] {
            for raw in ["1garbage", "-1", "NaN", String(repeating: "9", count: 45)] {
                let fields = swap.merging([key: raw]) { _, new in new }
                XCTAssertNil(convert(try subquery(fields)), "\(key): \(raw)")
                XCTAssertNil(convert(sdk(fields)), "\(key): \(raw)")
            }
        }
    }

    func testBothLiquidityAdaptersValidateBothAmountFields() throws {
        let fields = ["baseAssetId": "XOR", "targetAssetId": "VAL", "baseAssetAmount": "2.5", "targetAssetAmount": "5.25", "type": "Deposit"]
        for key in ["baseAssetAmount", "targetAssetAmount"] {
            let malformed = fields.merging([key: "1garbage"]) { _, new in new }
            XCTAssertNil(convert(try subquery(malformed)))
            XCTAssertNil(convert(sdk(malformed)))
        }
    }

    func testSubqueryAtomicAmountsCannotSilentlyBecomeZero() throws {
        for raw in ["garbage", "-1", "0.5"] {
            XCTAssertNil(convert(try subquery(["amount": raw, "isReward": true])), raw)
            XCTAssertNil(convert(try subquery(["hash": "hash", "module": "balances", "call": "transfer", "fee": raw, "success": true])), raw)
        }
    }
}
