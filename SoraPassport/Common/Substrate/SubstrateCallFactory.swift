/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FearlessUtils
import IrohaCrypto
import BigInt

protocol SubstrateCallFactoryProtocol {
    func migrate(irohaAddress: String, irohaKey: String, signature: String) throws -> RuntimeCall<MigrateCall>
}

final class SubstrateCallFactory: SubstrateCallFactoryProtocol {
    private let addressFactory = SS58AddressFactory()

    func migrate(irohaAddress: String, irohaKey: String, signature: String) throws -> RuntimeCall<MigrateCall> {
        let call = MigrateCall(irohaAddress: irohaAddress, irohaPublicKey: irohaKey, irohaSignature: signature)
        return RuntimeCall<MigrateCall>.migrate(call)

    }

    func transfer(to receiverAccountId: String,
                  asset: String,
                  amount: BigUInt) throws -> RuntimeCall<SoraTransferCall> {
        let call = SoraTransferCall(receiver: receiverAccountId,
                                    amount: amount,
                                    assetId: asset)
        return RuntimeCall<SoraTransferCall>.transfer(call)
    }
}
