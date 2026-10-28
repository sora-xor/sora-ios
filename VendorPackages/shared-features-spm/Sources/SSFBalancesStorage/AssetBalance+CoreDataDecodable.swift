import CoreData
import Foundation
import RobinHood
import SSFBalances

extension CDAssetBalance: CoreDataCodable {
    public var entityIdentifierFieldName: String { #keyPath(CDAssetBalance.balanceId) }

    public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: AssetBalanceInfo.CodingKeys.self)

        assetId = try container.decode(String.self, forKey: .assetId)
        chainId = try container.decode(String.self, forKey: .chainId)
        accountId = try container.decode(String.self, forKey: .accountId)
        balanceId = try container.decode(String.self, forKey: .balanceId)
        price = try? container.decodeIfPresent(Decimal.self, forKey: .price) as NSDecimalNumber?
        deltaPrice = try? container.decodeIfPresent(
            Decimal.self,
            forKey: .deltaPrice
        ) as NSDecimalNumber?

        balance = try? container.decodeIfPresent(Decimal.self, forKey: .balance) as NSDecimalNumber?

        lockedBalance = try? container.decodeIfPresent(
            Decimal.self,
            forKey: .lockedBalance
        ) as NSDecimalNumber?
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AssetBalanceInfo.CodingKeys.self)

        try container.encode(assetId, forKey: .assetId)
        try container.encode(chainId, forKey: .chainId)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(balanceId, forKey: .balanceId)
        try container.encodeIfPresent(price as Decimal?, forKey: .price)
        try container.encodeIfPresent(deltaPrice as Decimal?, forKey: .deltaPrice)
        try container.encodeIfPresent(balance as Decimal?, forKey: .balance)
        try container.encodeIfPresent(lockedBalance as Decimal?, forKey: .lockedBalance)
    }
}
