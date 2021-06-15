import Foundation
import IrohaCrypto
import FearlessUtils

extension TransactionHistoryItem {
    static func createFromSubscriptionResult(
        _ result: TransferSubscriptionResult,
        fee: Decimal,
        address: String,
        addressFactory: SS58AddressFactoryProtocol
    ) -> TransactionHistoryItem? {
        do {
            let typeRawValue = try addressFactory.type(fromAddress: address)

            let addressType = SNAddressType(typeRawValue.uint8Value) 

            guard let address = result.extrinsic.signature?.address.stringValue, let txOrigin = try? Data(hexString: address) else {
                return nil
            }

            let txReceiver = try Data(hexString: result.call.receiver)

            let sender = try addressFactory.address(
                fromPublicKey: AccountIdWrapper(rawData: txOrigin),
                type: addressType
            )
            let receiver = try addressFactory
                    .address(
                        fromPublicKey: AccountIdWrapper(rawData: txReceiver),
                        type: addressType
                    )
//TODO asset precision

            let timestamp = Int64(Date().timeIntervalSince1970)
            let amount = Decimal.fromSubstrateAmount(
                result.call.amount,
                precision: 18
            ) ?? .zero

            return TransactionHistoryItem(
                sender: sender,
                receiver: receiver,
                status: .success,
                txHash: result.extrinsicHash.toHex(includePrefix: true),
                timestamp: timestamp,
                amount: amount.stringWithPointSeparator,
                assetId: result.call.assetId,
                fee: fee.stringWithPointSeparator,
                blockNumber: result.blockNumber,
                txIndex: result.txIndex
            )

        } catch {
            return nil
        }
    }
}
