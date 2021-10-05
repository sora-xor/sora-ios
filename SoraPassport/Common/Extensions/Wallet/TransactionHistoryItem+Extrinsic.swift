/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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
            let extrinsic = result.processingResult.extrinsic
            let call = try extrinsic.call.map(to: RuntimeCall<SoraTransferCall>.self)

            let addressType = SNAddressType(typeRawValue.uint8Value) 

            guard let address = extrinsic.signature?.address.stringValue, let txOrigin = try? Data(hexString: address) else {
                return nil
            }

            let txReceiver = try Data(hexString: call.args
                                        .receiver)

            let sender = try addressFactory.address(
                fromAccountId: txOrigin,
                type: addressType
            )
            let receiver = try addressFactory
                    .address(
                        fromAccountId: txReceiver,
                        type: addressType
                    )
//TODO asset precision

            let timestamp = Int64(Date().timeIntervalSince1970)
            let amount = Decimal.fromSubstrateAmount(
                call.args.amount,
                precision: 18
            ) ?? .zero

            let status: Status = result.processingResult.isSuccess ? .success : .failed

            return TransactionHistoryItem(
                sender: sender,
                receiver: receiver,
                status: status,
                txHash: result.extrinsicHash.toHex(includePrefix: true),
                timestamp: timestamp,
                amount: amount.stringWithPointSeparator,
                assetId: call.args.assetId,
                fee: fee.stringWithPointSeparator,
                blockNumber: result.blockNumber,
                txIndex: result.txIndex
            )

        } catch {
            return nil
        }
    }
}
