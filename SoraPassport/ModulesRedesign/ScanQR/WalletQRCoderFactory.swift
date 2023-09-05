// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import CommonWallet
import IrohaCrypto
import FearlessUtils

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
        let accountId = try Data(hexString: receiverInfo.accountId)

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
