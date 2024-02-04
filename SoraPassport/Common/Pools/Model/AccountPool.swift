//
//  AccountPool.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 1/30/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import RobinHood

struct AccountPool: Codable {
    enum CodingKeys: String, CodingKey {
        case poolId
        case baseAssetId
        case targetAssetId
        case rewardAssetId
        case apy
        case baseAssetPooled
        case targetAssetPooled
        case accountPoolShare
    }
    
    let poolId: String
    let baseAssetId: String
    let targetAssetId: String
    let rewardAssetId: String = WalletAssetId.pswap.rawValue
    var apy: Decimal?
    var baseAssetPooled: Decimal?
    var targetAssetPooled: Decimal?
    var accountPoolShare: Decimal?
    var reservesId: String?
    
    init(
        poolId: String,
        baseAssetId: String,
        targetAssetId: String,
        apy: Decimal? = nil,
        baseAssetPooled: Decimal? = nil,
        targetAssetPooled: Decimal? = nil,
        accountPoolShare: Decimal? = nil,
        reservesId: String? = nil
    ) {
        self.poolId = poolId
        self.baseAssetId = baseAssetId
        self.targetAssetId = targetAssetId
        self.apy = apy
        self.baseAssetPooled = baseAssetPooled
        self.targetAssetPooled = targetAssetPooled
        self.accountPoolShare = accountPoolShare
        self.reservesId = reservesId
    }
    
    init(accountPool: AccountPool) {
        self.init(
            poolId: accountPool.poolId,
            baseAssetId: accountPool.baseAssetId,
            targetAssetId: accountPool.targetAssetId,
            apy: accountPool.apy,
            baseAssetPooled: accountPool.baseAssetPooled,
            targetAssetPooled: accountPool.targetAssetPooled,
            accountPoolShare: accountPool.accountPoolShare,
            reservesId: accountPool.reservesId
        )
    }
    
    func update(apy: Decimal?) -> AccountPool {
        var copy = AccountPool(accountPool: self)
        copy.apy = apy
        return copy
    }
}

extension AccountPool: Identifiable {
    var identifier: String { poolId }
}

extension AccountPool: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(poolId)
        hasher.combine(baseAssetId)
        hasher.combine(targetAssetId)
    }

    static func ==(lhs: AccountPool, rhs: AccountPool) -> Bool {
        lhs.poolId == rhs.poolId &&
        lhs.baseAssetId == rhs.baseAssetId &&
        lhs.targetAssetId == rhs.targetAssetId
    }
}

