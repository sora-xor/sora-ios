import Foundation
import CommonWallet
import BigInt
import IrohaCrypto
import FearlessUtils

extension AssetTransactionData {
    static func createTransaction(
        from item: TransactionHistoryItem,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        if item.callPath.isTransfer {
            return createLocalTransfer(
                from: item,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        } else if item.callPath.isSwap {
            return createLocalSwap(
                from: item,
                address: address,
                asset: asset
            )
        } else {
            return createLocalExtrinsic(
                from: item,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }
        
        // TODO: add other types of transactions
    }

    private static func createLocalSwap(
        from item: TransactionHistoryItem,
        address: String,
        asset: WalletAsset
    ) -> AssetTransactionData  {

        let swap = try? JSONDecoder.scaleCompatible().decode(RuntimeCall<SwapCall>.self, from: item.call).args
        let sourceType: UInt? = swap?.liquiditySourceType.first as? UInt
        let marketType: LiquiditySourceType = LiquiditySourceType(networkValue: sourceType)
        let amountStruct = swap?.amount.values.first
        let desired = amountStruct?.desired ?? 0
        let slip = amountStruct?.slip ?? 0

        let amountDecimal = Decimal.fromSubstrateAmount(slip, precision: asset.precision) ?? .zero
        let fromAmountDecimal = Decimal.fromSubstrateAmount(desired, precision: asset.precision) ?? .zero

        let feeDecimal: Decimal = {
            guard let feeValue = BigUInt(item.fee) else {
                return Decimal(string: item.fee) ?? .zero
            }

            return Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) ?? .zero
        }()
        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let lpFeeDecimal: Decimal = .zero
        let lpFee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: lpFeeDecimal),
            context: ["type": TransactionType.swap.rawValue]
        )

        return AssetTransactionData(
            transactionId: item.txHash,
            status: item.status.walletValue,
            assetId: swap?.outputAssetId ?? "?",
            peerId: swap?.inputAssetId ?? "??",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: marketType.rawValue,
            details: fromAmountDecimal.description,
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee, lpFee],
            timestamp: item.timestamp,
            type: TransactionType.swap.rawValue,
            reason: nil,
            context: nil)
    }

    private static func createLocalTransfer(
        from item: TransactionHistoryItem,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let peerAddress = (item.sender == address ? item.receiver : item.sender) ?? item.sender

        let accountId = try? addressFactory.accountId(
            fromAddress: peerAddress,
            type: networkType
        )

        let call = try? JSONDecoder.scaleCompatible().decode(RuntimeCall<SoraTransferCall>.self, from: item.call).args

        let assetId = call?.assetId ?? asset.identifier

        let peerId = accountId?.toHex() ?? peerAddress
        let feeDecimal: Decimal = {
            guard let feeValue = BigUInt(item.fee) else {
                return .zero
            }

            return Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) ?? .zero
        }()

        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let amount: Decimal = {
            if let call = call {
                return Decimal.fromSubstrateAmount(call.amount, precision: asset.precision) ?? .zero
            } else {
                return .zero
            }
        }()

        let type = item.sender == address ? TransactionType.outgoing :
            TransactionType.incoming

        return AssetTransactionData(
            transactionId: item.txHash,
            status: item.status.walletValue,
            assetId: assetId,
            peerId: peerId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [fee],
            timestamp: item.timestamp,
            type: type.rawValue,
            reason: nil,
            context: [TransactionContextKeys.extrinsicHash: item.txHash]
        )
    }

    private static func createLocalExtrinsic(
        from item: TransactionHistoryItem,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let amount: Decimal = {
            guard let amountValue = BigUInt(item.fee) else {
                return 0.0
            }

            return Decimal.fromSubstrateAmount(amountValue, precision: asset.precision) ?? 0.0
        }()

        let accountId = try? addressFactory.accountId(
            fromAddress: item.sender,
            type: networkType
        )

        let cfff = try? JSONDecoder.scaleCompatible().decode(RuntimeCall<SwapCall>.self, from: item.call)
        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: item.identifier,
            status: item.status.walletValue,
            assetId: asset.identifier,
            peerId: peerId,
            peerFirstName: item.callPath.moduleName,
            peerLastName: item.callPath.callName,
            peerName: "\(item.callPath.moduleName) \(item.callPath.callName)",
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: item.timestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: nil,
            context: [TransactionContextKeys.extrinsicHash: item.txHash]
        )
    }
}
