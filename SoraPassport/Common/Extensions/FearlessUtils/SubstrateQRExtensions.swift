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

import SSFUtils
import Foundation
import IrohaCrypto
import SSFQRService

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
