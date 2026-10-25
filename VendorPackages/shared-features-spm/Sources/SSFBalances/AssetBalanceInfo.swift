import Foundation
import RobinHood
import SSFModels

public struct AssetBalanceInfo: Codable {
    public enum CodingKeys: String, CodingKey {
        case chainId
        case assetId
        case accountId
        case balanceId
        case price
        case deltaPrice
        case balance
        case lockedBalance
    }

    public let balanceId: String
    public let chainId: String
    public let assetId: String
    public let accountId: String
    public let price: Decimal?
    public let deltaPrice: Decimal?
    public let balance: Decimal?
    public let lockedBalance: Decimal?

    public var totalBalance: Decimal? {
        guard let price, let balance = balance else { return nil }
        return price * balance
    }

    public var chainAssetId: String {
        "\(chainId):\(assetId)"
    }

    public init(
        chainId: String,
        assetId: String,
        accountId: String,
        price: Decimal?,
        deltaPrice: Decimal?,
        balance: Decimal?,
        lockedBalance: Decimal?
    ) {
        balanceId = "\(chainId):\(assetId):\(accountId)"
        self.chainId = chainId
        self.assetId = assetId
        self.accountId = accountId
        self.price = price
        self.deltaPrice = deltaPrice
        self.balance = balance
        self.lockedBalance = lockedBalance
    }
}

extension AssetBalanceInfo: Identifiable {
    public var identifier: String {
        balanceId
    }
}

extension AssetBalanceInfo: Hashable {
    public static func == (lhs: AssetBalanceInfo, rhs: AssetBalanceInfo) -> Bool {
        lhs.balanceId == rhs.balanceId &&
            lhs.price == rhs.price &&
            lhs.deltaPrice == rhs.deltaPrice &&
            lhs.balance == rhs.balance &&
            lhs.lockedBalance == rhs.lockedBalance
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(balanceId)
        hasher.combine(price)
        hasher.combine(deltaPrice)
        hasher.combine(balance)
        hasher.combine(lockedBalance)
    }
}
