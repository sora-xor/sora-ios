import Foundation
import CommonWallet
import IrohaCrypto
import FearlessUtils
import BigInt

extension TransactionHistoryItem {
    static func createFromTransferInfo(_ info: TransferInfo,
                                       transactionHash: Data,
                                       networkType: SNAddressType,
                                       addressFactory: SS58AddressFactoryProtocol) throws
        -> TransactionHistoryItem {

        let sender:String
        let receiver:String

        let totalFee = info.fees.reduce(Decimal(0)) { (total, fee) in total + fee.value.decimalValue }

        let timestamp = Int64(Date().timeIntervalSince1970)

        let callPath: CallCodingPath
        let encodedCall: Data
        switch info.type {
        case .swap:
            sender = info.source
            receiver = info.destination
            let amountCall = info.amountCall ?? [:]
            let sourceType: String = info.context?[TransactionContextKeys.marketType] ?? ""
            let marketType: LiquiditySourceType = LiquiditySourceType(rawValue: sourceType) ?? .smart
            let call = try? SubstrateCallFactory().swap(from: sender, to: receiver, amountCall: amountCall, type: marketType.code, filter: marketType.filter)
            callPath = CallCodingPath(moduleName: call!.moduleName, callName: call!.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)
        default:
            let senderAccountId = try Data(hexString: info.source)
            let receiverAccountId = try Data(hexString: info.destination)
            sender = try addressFactory.address(fromAccountId: senderAccountId,
                                                    type: networkType)
            receiver = try addressFactory.address(fromAccountId: receiverAccountId,
                                                      type: networkType)
            callPath = CallCodingPath.transfer
            let callArgs = SoraTransferCall(receiver: receiver,
                                            amount: info.amount.decimalValue.toSubstrateAmount(precision: 18) ?? 0,
                                            assetId: info.asset)
            let call = RuntimeCall<SoraTransferCall>(
                moduleName: callPath.moduleName,
                callName: callPath.callName,
                args: callArgs
            )
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)
        }

        return TransactionHistoryItem(
            sender: sender,
            receiver: receiver,
            status: .pending,
            txHash: transactionHash.toHex(includePrefix: true),
            timestamp: timestamp,
            fee: totalFee.stringWithPointSeparator,
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
