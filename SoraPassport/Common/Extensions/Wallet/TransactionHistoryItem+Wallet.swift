/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import SoraKeystore
import IrohaCrypto
import FearlessUtils
import BigInt

extension TransactionHistoryItem {
    static func createFromTransferInfo(
        _ info: TransferInfo,
        transactionHash: Data,
        networkType: SNAddressType,
        addressFactory: SS58AddressFactoryProtocol
    ) throws -> TransactionHistoryItem {

        let lpFee = String(info.fees.first(where: { $0.feeDescription.type == "lp" })?.value.decimalValue.toSubstrateAmount(precision: 18) ?? BigUInt(0))
        let transactionFee: String = String(info.fees.first(where: { $0.feeDescription.type == "fee" })?.value.decimalValue.toSubstrateAmount(precision: 18) ?? BigUInt(0))

        let timestamp = Int64(Date().timeIntervalSince1970)

        let callPath: CallCodingPath
        let encodedCall: Data
        switch info.type {
        case .swap:
            let sender = info.asset
            let receiver = info.destination
            let amountCall = info.amountCall ?? [:]
            let sourceType: String = info.context?[TransactionContextKeys.marketType] ?? ""
            let marketType: LiquiditySourceType = LiquiditySourceType(rawValue: sourceType) ?? .smart
            let call = try? SubstrateCallFactory().swap(
                from: sender,
                to: receiver,
                amountCall: amountCall,
                type: marketType.code,
                filter: marketType.filter
            )
            callPath = CallCodingPath(moduleName: call!.moduleName, callName: call!.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)

        case .liquidityAdd, .liquidityAddNewPool:
            let dexId: String = info.context?[TransactionContextKeys.dex] ?? "0"
            let assetA: String = info.source
            let assetB: String = info.destination
            let desiredA =  AmountDecimal(string: info.context?[TransactionContextKeys.firstAssetAmount] ?? "0")!
            let desiredB =  AmountDecimal(string: info.context?[TransactionContextKeys.secondAssetAmount] ?? "0")!
            let slippage =  AmountDecimal(string: info.context?[TransactionContextKeys.slippage] ?? "0")!
            let minA = desiredA.decimalValue * (1 - slippage.decimalValue / 100)
            let minB = desiredB.decimalValue * (1 - slippage.decimalValue / 100)

            let call = try? SubstrateCallFactory().depositLiquidity(
                dexId: dexId,
                assetA: assetA,
                assetB: assetB,
                desiredA: desiredA.decimalValue.toSubstrateAmount(precision: 18) ?? 0,
                desiredB: desiredB.decimalValue.toSubstrateAmount(precision: 18) ?? 0,
                minA: minA.toSubstrateAmount(precision: 18) ?? 0,
                minB: minB.toSubstrateAmount(precision: 18) ?? 0
            )
            callPath = CallCodingPath(moduleName: call!.moduleName, callName: call!.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)

        case .liquidityAddToExistingPoolFirstTime:
            //TODO: utility.batchAll with poolXYK.initializePool and poolXYK.depositLiquidity
            callPath = CallCodingPath(moduleName: "Stub", callName: "Stub")
            encodedCall = Data()

        case .liquidityRemoval:
            let dexId: String = info.context?[TransactionContextKeys.dex] ?? "0"
            let assetA: String = info.source
            let assetB: String = info.destination
            let desiredA = AmountDecimal(string: info.context?[TransactionContextKeys.firstAssetAmount] ?? "0")!
            let desiredB = AmountDecimal(string: info.context?[TransactionContextKeys.secondAssetAmount] ?? "0")!
            let slippage =  AmountDecimal(string: info.context?[TransactionContextKeys.slippage] ?? "0")!
            let minA = desiredA.decimalValue * (1 - slippage.decimalValue / 100)
            let minB = desiredB.decimalValue * (1 - slippage.decimalValue / 100)

            let call = try? SubstrateCallFactory().withdrawLiquidityCall(
                dexId: dexId,
                assetA: assetA,
                assetB: assetB,
                assetDesired: desiredA.decimalValue.toSubstrateAmount(precision: 18) ?? 0 ,
                minA: minA.toSubstrateAmount(precision: 18) ?? 0,
                minB: minB.toSubstrateAmount(precision: 18) ?? 0
            )
            callPath = CallCodingPath(moduleName: call!.moduleName, callName: call!.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)

        // TODO: impl
        case .incoming, .outgoing, .migration, .reward, .slash, .extrinsic, .referral:
            let receiverAccountId = try Data(hexString: info.destination)

            callPath = CallCodingPath.transfer
            let callArgs = SoraTransferCall(receiver: MultiAddress.accoundId(receiverAccountId),
                                            amount: info.amount.decimalValue.toSubstrateAmount(precision: 18) ?? 0,
                                            assetId: AssetId(wrappedValue: info.asset))
            let call = RuntimeCall<SoraTransferCall>(
                moduleName: callPath.moduleName,
                callName: callPath.callName,
                args: callArgs
            )
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)
        }

        return TransactionHistoryItem(
            sender: SelectedWalletSettings.shared.currentAccount!.address,
            receiver: info.destination,
            status: .pending,
            txHash: transactionHash.toHex(includePrefix: true),
            timestamp: timestamp,
            fee: transactionFee,
            lpFee: lpFee,
            blockNumber: nil,
            txIndex: nil,
            callPath: callPath,
            call: encodedCall
        )
    }
}

extension TransactionHistoryItem.Status {
    var walletValue: AssetTransactionStatus {
        switch self {
        case .success:
            return .commited
        case .failed:
            return .rejected
        case .pending:
            return .pending
        }
    }
}
