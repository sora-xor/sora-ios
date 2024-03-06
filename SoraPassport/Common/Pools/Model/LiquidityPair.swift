//
//  LiquidityPair.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 2/4/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import RobinHood
import BigInt

public struct LiquidityPair: Codable {
    enum CodingKeys: String, CodingKey {
        case pairId
        case chainId
        case baseAssetId
        case targetAssetId
        case rewardAssetId
        case reserves
    }
    
    let pairId: String
    let chainId: String?
    let baseAssetId: String
    let targetAssetId: String
    let rewardAssetId: String = WalletAssetId.pswap.rawValue
    let reserves: BigUInt?
    var apy: Decimal?
    var reservesId: String?
    
    init(
        pairId: String,
        chainId: String?, 
        baseAssetId: String, 
        targetAssetId: String,
        reserves: BigUInt? = nil,
        apy: Decimal? = nil,
        reservesId: String? = nil
    ) {
        self.pairId = pairId
        self.chainId = chainId
        self.baseAssetId = baseAssetId
        self.targetAssetId = targetAssetId
        self.reserves = reserves
        self.apy = apy
        self.reservesId = reservesId
    }
    
     init(pair: LiquidityPair) {
        self.init(
            pairId: pair.pairId,
            chainId: pair.chainId,
            baseAssetId: pair.baseAssetId,
            targetAssetId: pair.targetAssetId,
            reserves: pair.reserves,
            apy: pair.apy,
            reservesId: pair.reservesId
        )
    }
    
    func update(reservesId: String?) -> LiquidityPair {
        var copy = LiquidityPair(pair: self)
        copy.reservesId = reservesId
        return copy
    }
    
    func update(apy: Decimal?) -> LiquidityPair {
        var copy = LiquidityPair(pair: self)
        copy.apy = apy
        return copy
    }
}

extension LiquidityPair: Identifiable {
    public var identifier: String { pairId }
}

extension LiquidityPair: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(pairId)
        hasher.combine(chainId)
        hasher.combine(baseAssetId)
        hasher.combine(targetAssetId)
    }

    public static func ==(lhs: LiquidityPair, rhs: LiquidityPair) -> Bool {
        lhs.pairId == rhs.pairId &&
        lhs.chainId == rhs.chainId &&
        lhs.baseAssetId == rhs.baseAssetId &&
        lhs.targetAssetId == rhs.targetAssetId
    }
}
