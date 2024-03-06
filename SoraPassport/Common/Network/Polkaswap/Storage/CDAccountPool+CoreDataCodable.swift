//
//  CDAccountPool+CoreDataCodable.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 2/4/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import RobinHood
import CoreData

extension CDAccountPool: CoreDataCodable {
    var entityIdentifierFieldName: String { #keyPath(CDAccountPool.poolId) }
    
    public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: AccountPool.CodingKeys.self)

        poolId = try container.decode(String.self, forKey: .poolId)
        accountId = try container.decode(String.self, forKey: .accountId)
        chainId = try container.decode(String.self, forKey: .chainId)
        baseAssetId = try container.decode(String.self, forKey: .baseAssetId)
        targetAssetId = try container.decode(String.self, forKey: .targetAssetId)
        rewardAssetId = try container.decode(String.self, forKey: .rewardAssetId)
//        apy = try container.decodeIfPresent(Decimal.self, forKey: .apy)
//        baseAssetPooled = try container.decodeIfPresent(Decimal.self, forKey: .baseAssetPooled)
//        targetAssetPooled = try container.decodeIfPresent(Decimal.self, forKey: .targetAssetPooled)
//        accountPoolShare = try container.decodeIfPresent(Decimal.self, forKey: .accountPoolShare)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AccountPool.CodingKeys.self)

        try container.encode(poolId, forKey: .poolId)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(chainId, forKey: .chainId)
        try container.encode(baseAssetId, forKey: .baseAssetId)
        try container.encode(targetAssetId, forKey: .targetAssetId)
        try container.encode(rewardAssetId, forKey: .rewardAssetId)
//        try container.encodeIfPresent(apy, forKey: .apy)
//        try container.encodeIfPresent(baseAssetPooled, forKey: .baseAssetPooled)
//        try container.encodeIfPresent(targetAssetPooled, forKey: .targetAssetPooled)
//        try container.encodeIfPresent(accountPoolShare, forKey: .accountPoolShare)
    }
}
