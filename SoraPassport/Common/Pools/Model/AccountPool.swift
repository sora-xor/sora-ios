//
//  AccountPool.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 1/30/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import RobinHood

public struct AccountPool: Codable {
    enum CodingKeys: String, CodingKey {
        case poolId
        case accountId
        case chainId
        case baseAssetId
        case targetAssetId
        case rewardAssetId
        case apy
        case baseAssetPooled
        case targetAssetPooled
        case accountPoolShare
    }
    
    let poolId: String
    let accountId: String
    let chainId: String
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
        accountId: String,
        chainId: String,
        baseAssetId: String,
        targetAssetId: String,
        apy: Decimal? = nil,
        baseAssetPooled: Decimal? = nil,
        targetAssetPooled: Decimal? = nil,
        accountPoolShare: Decimal? = nil,
        reservesId: String? = nil
    ) {
        self.poolId = poolId
        self.accountId = accountId
        self.chainId = chainId
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
            accountId: accountPool.accountId,
            chainId: accountPool.chainId,
            baseAssetId: accountPool.baseAssetId,
            targetAssetId: accountPool.targetAssetId,
            apy: accountPool.apy,
            baseAssetPooled: accountPool.baseAssetPooled,
            targetAssetPooled: accountPool.targetAssetPooled,
            accountPoolShare: accountPool.accountPoolShare,
            reservesId: accountPool.reservesId
        )
    }
    
    func update(reservesId: String?) -> AccountPool {
        var copy = AccountPool(accountPool: self)
        copy.reservesId = reservesId
        return copy
    }
    
    func update(apy: Decimal?) -> AccountPool {
        var copy = AccountPool(accountPool: self)
        copy.apy = apy
        return copy
    }
}

extension AccountPool: Identifiable {
    public var identifier: String { poolId }
}

extension AccountPool: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(poolId)
        hasher.combine(baseAssetId)
        hasher.combine(targetAssetId)
    }

    public static func ==(lhs: AccountPool, rhs: AccountPool) -> Bool {
        lhs.poolId == rhs.poolId &&
        lhs.baseAssetId == rhs.baseAssetId &&
        lhs.targetAssetId == rhs.targetAssetId
    }
}

