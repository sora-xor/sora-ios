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
            let addressType = SNAddressType(typeRawValue.uint8Value)
            let extrinsic = result.processingResult.extrinsic
            let timestamp = Int64(Date().timeIntervalSince1970)

            guard let author = try extrinsic.signature?.address.map(to: MultiAddress.self) else {
                return nil
            }
            let sender: String = try addressFactory.address(
                fromAccountId: author.data,
                type: addressType
            )
            var receiver: String = ""

            if let call = try? extrinsic.call.map(to: RuntimeCall<SoraTransferCall>.self) {
                receiver = try addressFactory
                    .address(
                        fromAccountId: call.args
                            .receiver.data,
                        type: addressType
                    )
            }

            let encodedCall = try JSONEncoder.scaleCompatible().encode(extrinsic.call)

            return TransactionHistoryItem(
                sender: sender,
                receiver: receiver,
                status: result.processingResult.isSuccess ? .success : .failed,
                txHash: result.extrinsicHash.toHex(includePrefix: true),
                timestamp: timestamp,
                fee: String(result.processingResult.fee ?? 0),
                lpFee: nil,
                blockNumber: result.blockNumber,
                txIndex: result.txIndex,
                callPath: result.processingResult.callPath,
                call: encodedCall
            )
        } catch let error {
            return nil
        }
    }
}
