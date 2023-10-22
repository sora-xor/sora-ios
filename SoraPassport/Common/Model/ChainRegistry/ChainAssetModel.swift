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

import Combine
import Foundation
import RobinHood

class ChainAssetModel: Codable {
    let assetId: String
    let staking: StakingType?
    let purchaseProviders: [PurchaseProvider]?
    let type: ChainAssetType
    var asset: AssetModel!
    weak var chain: ChainModel?

    var isUtility: Bool { asset.assetId == WalletAssetId.xor.rawValue }//chain?.identifier }

    init(
        assetId: String,
        staking: StakingType? = nil,
        purchaseProviders: [PurchaseProvider]? = nil,
        type: ChainAssetType,
        asset: AssetModel,
        chain: ChainModel
    ) {
        self.assetId = assetId
        self.staking = staking
        self.purchaseProviders = purchaseProviders
        self.type = type
        self.asset = asset
        self.chain = chain
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        assetId = try container.decode(String.self, forKey: .assetId)
        staking = try? container.decode(StakingType.self, forKey: .staking)
        purchaseProviders = try? container.decode([PurchaseProvider]?.self, forKey: .purchaseProviders)
        let type = try? container.decode(ChainAssetType?.self, forKey: .type)
        self.type = type ?? ChainAssetType.normal
    }
}

extension ChainAssetModel: Hashable {
    static func == (lhs: ChainAssetModel, rhs: ChainAssetModel) -> Bool {
        lhs.assetId == rhs.assetId &&
            lhs.asset == rhs.asset &&
            lhs.staking == rhs.staking &&
            lhs.purchaseProviders == rhs.purchaseProviders &&
            lhs.type == rhs.type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(assetId)
    }
}

enum PurchaseProvider: String, Codable {
    case moonpay
    case ramp
}

enum StakingType: String, Codable {
    case relayChain = "relaychain"
    case parachain
}
