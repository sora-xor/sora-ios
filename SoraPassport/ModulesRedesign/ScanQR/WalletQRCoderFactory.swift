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

final class WalletQREncoder: WalletQREncoderProtocol {
    let username: String?
    let networkType: SNAddressType
    let publicKey: Data

    private lazy var substrateEncoder = AddressQREncoder()
    private lazy var addressFactory = SS58AddressFactory()

    init(networkType: SNAddressType, publicKey: Data, username: String?) {
        self.networkType = networkType
        self.publicKey = publicKey
        self.username = username
    }

    func encode(receiverInfo: ReceiveInfo) throws -> Data {
        let accountId = try Data(hexStringSSF: receiverInfo.accountId)

        let address = try addressFactory.address(fromAccountId: accountId, type: networkType)

        let info = SoraSubstrateQRInfo(address: address,
                                       rawPublicKey: publicKey,
                                       username: username,
                                       assetId: receiverInfo.assetId!,
                                       amount: receiverInfo.amount?.stringValue ?? "")
        return try substrateEncoder.encode(info: info)
    }
}

final class WalletQRDecoder: WalletQRDecoderProtocol {
    private lazy var addressFactory = SS58AddressFactory()
    private let substrateDecoder: AddressQRDecoder
    private let assets: [WalletAsset]

    init(networkType: SNAddressType, assets: [WalletAsset]) {
        substrateDecoder = AddressQRDecoder(chainType: networkType)
        self.assets = assets
    }

    func decode(data: Data) throws -> ReceiveInfo {
        let info: SoraSubstrateQRInfo = try substrateDecoder.decode(data: data)

        let accountId = try addressFactory.accountId(fromAddress: info.address,
                                                     type: substrateDecoder.chainType)
        guard let asset = assets.first(where: { $0.identifier == info.assetId }) else {
            throw TransferPresenterError.missingAsset
        }
        return ReceiveInfo(accountId: accountId.toHex(),
                           assetId: asset.identifier,
                           amount: AmountDecimal(string: info.amount ?? ""),
                           details: nil)
    }
}

final class WalletQRCoderFactory: WalletQRCoderFactoryProtocol {
    let networkType: SNAddressType
    let publicKey: Data
    let username: String?
    let assets: [WalletAsset]

    init(networkType: SNAddressType, publicKey: Data, username: String?, assets: [WalletAsset]) {
        self.networkType = networkType
        self.publicKey = publicKey
        self.username = username
        self.assets = assets
    }

    func createEncoder() -> WalletQREncoderProtocol {
        WalletQREncoder(networkType: networkType,
                        publicKey: publicKey,
                        username: username)
    }

    func createDecoder() -> WalletQRDecoderProtocol {
        WalletQRDecoder(networkType: networkType, assets: assets)
    }
}
