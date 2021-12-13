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
        let senderAccountId = try Data(hexString: info.source)
        let receiverAccountId = try Data(hexString: info.destination)

        let sender = try addressFactory.address(fromAccountId: senderAccountId,
                                                type: networkType)

        let receiver = try addressFactory.address(fromAccountId: receiverAccountId,
                                                  type: networkType)

        let totalFee = info.fees.reduce(Decimal(0)) { (total, fee) in total + fee.value.decimalValue }

        let timestamp = Int64(Date().timeIntervalSince1970)

        let callPath = CallCodingPath.transfer
        let callArgs = SoraTransferCall(receiver: receiver,
                                        amount: info.amount.decimalValue.toSubstrateAmount(precision: 18) ?? 0,
                                        assetId: info.asset)
        let call = RuntimeCall<SoraTransferCall>(
            moduleName: callPath.moduleName,
            callName: callPath.callName,
            args: callArgs
        )
        let encodedCall = try JSONEncoder.scaleCompatible().encode(call)

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
