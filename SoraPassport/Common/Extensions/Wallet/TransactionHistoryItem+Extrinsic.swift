// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import IrohaCrypto
import SSFUtils

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
                            .receiver,
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
