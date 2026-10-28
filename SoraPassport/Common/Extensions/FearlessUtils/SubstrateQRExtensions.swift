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

import SSFUtils
import Foundation
import IrohaCrypto

public struct SoraSubstrateQRInfo: Equatable {
    public let prefix: String
    public let address: String
    public let rawPublicKey: Data
    public let username: String?
    public let assetId: String
    public let amount: String?

    public init(prefix: String = SubstrateQRConstants.prefix,
                address: String,
                rawPublicKey: Data,
                username: String?,
                assetId: String,
                amount: String?) {
        self.prefix = prefix
        self.address = address
        self.rawPublicKey = rawPublicKey
        self.username = username
        self.assetId = assetId
        self.amount = amount
    }
}

extension AddressQREncoder {

    public func encode(info: SoraSubstrateQRInfo) throws -> Data {
        let fields: [String] = [
            info.prefix,
            info.address,
            info.rawPublicKey.toHex(includePrefix: true),
            "",
            info.assetId,
            info.amount ?? ""
        ]

        let separator: String = ":"
        guard let data = fields.joined(separator: separator).data(using: .utf8) else {
            throw QREncoderError.brokenData
        }

        return data
    }
}

extension AddressQRDecoder {
    public func decode(data: Data) throws -> SoraSubstrateQRInfo {
        guard let fields = String(data: data, encoding: .utf8)?
            .components(separatedBy: separator) else {
            throw QRDecoderError.brokenFormat
        }

        guard fields.count >= 5 else {
            throw QRDecoderError.unexpectedNumberOfFields
        }

        guard fields[0] == prefix else {
            throw QRDecoderError.undefinedPrefix
        }

        let addressFactory = SS58AddressFactory()

        let address = fields[1]
        let accountId = try addressFactory.accountId(fromAddress: address, type: chainType)
        let publicKey = try Data(hexStringSSF: fields[2])

        guard publicKey.matchPublicKeyToAccountId(accountId) else {
            throw QRDecoderError.accountIdMismatch
        }

        let username = fields[3]

        let assetId = fields[4]
        
        var amount: String? = nil
        if fields.count > 5 {
            amount = fields[5]
        }

        return SoraSubstrateQRInfo(prefix: prefix,
                                   address: address,
                                   rawPublicKey: publicKey,
                                   username: username,
                                   assetId: assetId,
                                   amount: amount)
    }
}
