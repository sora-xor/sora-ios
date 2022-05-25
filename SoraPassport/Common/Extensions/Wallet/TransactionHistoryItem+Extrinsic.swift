import Foundation
import IrohaCrypto
import FearlessUtils

extension TransactionHistoryItem {
    static func createFromSubscriptionResult(
        _ result: TransactionSubscriptionResult,
        fee: Decimal,
        address: String,
        addressFactory: SS58AddressFactoryProtocol
    ) -> TransactionHistoryItem? {
        do {
            let typeRawValue = try addressFactory.type(fromAddress: address)
            let addressType = SNAddressType(typeRawValue.uint8Value)
            let extrinsic = result.processingResult.extrinsic
            let timestamp = Int64(Date().timeIntervalSince1970)
            guard let address = extrinsic.signature?.address.stringValue, let txOrigin = try? Data(hexString: address) else {
                return nil
            }
            var sender: String = ""
            var receiver: String = ""

            if let call = try? extrinsic.call.map(to: RuntimeCall<SoraTransferCall>.self) {

                let txReceiver = try Data(hexString: call.args
                                            .receiver)

                sender = try addressFactory.address(
                    fromAccountId: txOrigin,
                    type: addressType
                )
                receiver = try addressFactory
                    .address(
                        fromAccountId: txReceiver,
                        type: addressType
                    )
            }

            if let call = try? extrinsic.call.map(to: RuntimeCall<SwapCall>.self) {
                sender = call.args.inputAssetId
                receiver = call.args.outputAssetId
            }
            
            let status: Status = result.processingResult.isSuccess ? .success : .failed

            let encodedCall = try JSONEncoder.scaleCompatible().encode(extrinsic.call)

            return TransactionHistoryItem(
                sender: sender,
                receiver: receiver,
                status: result.processingResult.isSuccess ? .success : .failed,
                txHash: result.extrinsicHash.toHex(includePrefix: true),
                timestamp: timestamp,
                fee: String(result.processingResult.fee ?? 0),
                blockNumber: result.blockNumber,
                txIndex: result.txIndex,
                callPath: result.processingResult.callPath,
                call: encodedCall
            )
        } catch {
            return nil
        }
    }
}
