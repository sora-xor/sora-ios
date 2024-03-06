//
//  CDLiquidityPair+CoreDataCodable.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 2/4/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import RobinHood
import CoreData

extension CDLiquidityPair: CoreDataCodable {
    var entityIdentifierFieldName: String { #keyPath(CDLiquidityPair.pairId) }
    
    public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: LiquidityPair.CodingKeys.self)

        pairId = try container.decode(String.self, forKey: .pairId)
        chainId = try container.decode(String.self, forKey: .chainId)
        baseAssetId = try container.decode(String.self, forKey: .baseAssetId)
        targetAssetId = try container.decode(String.self, forKey: .targetAssetId)
        rewardAssetId = try container.decode(String.self, forKey: .rewardAssetId)

//        let decodedReserves = try container.decode(Decimal?.self, forKey: .reserves)
//        reserves = NSDecimalNumber(decimal: decodedReserves ?? Decimal(0))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LiquidityPair.CodingKeys.self)

        try container.encode(pairId, forKey: .pairId)
        try container.encode(chainId, forKey: .chainId)
        try container.encode(baseAssetId, forKey: .baseAssetId)
        try container.encode(targetAssetId, forKey: .targetAssetId)
        try container.encode(rewardAssetId, forKey: .rewardAssetId)

//        let encodedReserves = NSDecimalNumber(decimal: (reserves ?? NSDecimalNumber(0)) as Decimal)
//        try container.encode(encodedReserves, forKey: .reserves)
    }
}
