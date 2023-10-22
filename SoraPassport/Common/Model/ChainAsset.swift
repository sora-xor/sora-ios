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

typealias ChainAssetKey = String

struct ChainAsset: Equatable, Hashable {
    let chain: ChainModel
    let asset: AssetModel

    var chainAssetType: ChainAssetType {
//        asset.type
        .normal
    }

    var currencyId: String? {
        return asset.symbol
//        switch chainAssetType {
//        case .normal:
//            return nil
//        case .ormlChain, .ormlAsset:
//            let tokenSymbol = TokenSymbol(symbol: asset.symbol)
//            return CurrencyId.token(symbol: tokenSymbol)
//        case .foreignAsset:
//            guard let foreignAssetId = asset.currencyId else {
//                return nil
//            }
//            return CurrencyId.foreignAsset(foreignAsset: foreignAssetId)
//        case .stableAssetPoolToken:
//            guard let stableAssetPoolTokenId = asset.currencyId else {
//                return nil
//            }
//            return CurrencyId.stableAssetPoolToken(stableAssetPoolToken: stableAssetPoolTokenId)
//        case .liquidCroadloan:
//            guard
//                let currencyId = asset.currencyId,
//                let liquidCroadloanId = UInt16(currencyId)
//            else {
//                return nil
//            }
//            let liquidCroadloan = LiquidCroadloan(symbol: liquidCroadloanId)
//            return CurrencyId.liquidCroadloan(symbol: liquidCroadloan)
//        case .vToken:
//            let tokenSymbol = TokenSymbol(symbol: asset.symbol)
//            return CurrencyId.vToken(symbol: tokenSymbol)
//        case .vsToken:
//            let tokenSymbol = TokenSymbol(symbol: asset.symbol)
//            return CurrencyId.vsToken(symbol: tokenSymbol)
//        case .stable:
//            let tokenSymbol = TokenSymbol(symbol: asset.symbol)
//            return CurrencyId.stable(symbol: tokenSymbol)
//        }
    }

    func uniqueKey(accountId: AccountId) -> ChainAssetKey {
        [asset.id, chain.chainId, accountId.value.toHex()].joined(separator: ":")
    }
}

struct ChainAssetId: Equatable, Codable {
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id
}

extension ChainAsset {
    var chainAssetId: ChainAssetId {
        ChainAssetId(chainId: chain.chainId, assetId: asset.id)
    }

//    var assetDisplayInfo: AssetBalanceDisplayInfo { asset.displayInfo(with: chain.icon) }

    var storagePath: StorageCodingPath {
        var storagePath: StorageCodingPath
        switch chainAssetType {
        case .normal:
            storagePath = StorageCodingPath.account
        case
            .ormlChain,
            .ormlAsset,
            .foreignAsset,
            .stableAssetPoolToken,
            .liquidCroadloan,
            .vToken,
            .vsToken,
            .stable:
            storagePath = StorageCodingPath.tokens
        }

        return storagePath
    }
}

enum ChainAssetType: String, Codable {
    case normal
    case ormlChain
    case ormlAsset
    case foreignAsset
    case stableAssetPoolToken
    case liquidCroadloan
    case vToken
    case vsToken
    case stable
}
