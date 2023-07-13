import CoreData
import Foundation
import FearlessUtils
import RobinHood

typealias PoolModel = PoolInfo

struct PoolInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case baseAssetId
        case targetAssetId
        case poolId
        case isFavorite
        case accountId
    }

    let baseAssetId: String
    let targetAssetId: String
    let poolId: String
    var isFavorite: Bool
    let accountId: String
    
    var yourPoolShare: Decimal?
    var baseAssetPooledByAccount: Decimal?
    var targetAssetPooledByAccount: Decimal?
    var baseAssetPooledTotal: Decimal?
    var targetAssetPooledTotal: Decimal?
    var totalIssuances: Decimal?
    var baseAssetReserves: Decimal?
    var targetAssetReserves: Decimal?
    var accountPoolBalance: Decimal?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        baseAssetId = try container.decode(String.self, forKey: .baseAssetId)
        targetAssetId = try container.decode(String.self, forKey: .targetAssetId)
        poolId = try container.decode(String.self, forKey: .poolId)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        accountId = try container.decode(String.self, forKey: .accountId)
    }

    init(
        baseAssetId: String,
        targetAssetId: String,
        poolId: String,
        isFavorite: Bool,
        accountId: String,
        yourPoolShare: Decimal? = nil,
        baseAssetPooledByAccount: Decimal? = nil,
        targetAssetPooledByAccount: Decimal? = nil,
        baseAssetPooledTotal: Decimal? = nil,
        targetAssetPooledTotal: Decimal? = nil,
        totalIssuances: Decimal? = nil,
        baseAssetReserves: Decimal? = nil,
        targetAssetReserves: Decimal? = nil,
        accountPoolBalance: Decimal? = nil
    ) {
        self.baseAssetId = baseAssetId
        self.targetAssetId = targetAssetId
        self.poolId = poolId
        self.isFavorite = isFavorite
        self.accountId = accountId
        self.yourPoolShare = yourPoolShare
        self.baseAssetPooledByAccount = baseAssetPooledByAccount
        self.targetAssetPooledByAccount = targetAssetPooledByAccount
        self.baseAssetPooledTotal = baseAssetPooledTotal
        self.targetAssetPooledTotal = targetAssetPooledTotal
        self.totalIssuances = totalIssuances
        self.baseAssetReserves = baseAssetReserves
        self.targetAssetReserves = targetAssetReserves
        self.accountPoolBalance = accountPoolBalance
    }
    
    public func replacingVisible(_ newPoolInfo: PoolInfo) -> PoolInfo {
        PoolInfo(baseAssetId: baseAssetId,
                 targetAssetId: targetAssetId,
                 poolId: poolId,
                 isFavorite: newPoolInfo.isFavorite,
                 accountId: accountId,
                 yourPoolShare: yourPoolShare,
                 baseAssetPooledByAccount: baseAssetPooledByAccount,
                 targetAssetPooledByAccount: targetAssetPooledByAccount,
                 baseAssetPooledTotal: baseAssetPooledTotal,
                 targetAssetPooledTotal: targetAssetPooledTotal,
                 totalIssuances: totalIssuances,
                 baseAssetReserves: baseAssetReserves,
                 targetAssetReserves: targetAssetReserves)
    }
}

extension PoolInfo: Identifiable {
    var identifier: String { poolId }
    var id: String { poolId }
}

extension PoolModel {
    typealias Id = String
}

extension CDPoolInfo: CoreDataCodable {
    var entityIdentifierFieldName: String { #keyPath(CDPoolInfo.poolId) }

    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let poolInfo = try PoolInfo(from: decoder)

        baseAssetId = poolInfo.baseAssetId
        targetAssetId = poolInfo.targetAssetId
        poolId = poolInfo.poolId
        isFavorite = poolInfo.isFavorite
        accountId = poolInfo.accountId
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PoolInfo.CodingKeys.self)

        try container.encode(baseAssetId, forKey: .baseAssetId)
        try container.encode(targetAssetId, forKey: .targetAssetId)
        try container.encode(poolId, forKey: .poolId)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(accountId, forKey: .accountId)
    }
}

extension PoolInfo: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(poolId)
    }

    static func ==(lhs: PoolInfo, rhs: PoolInfo) -> Bool {
        return lhs.poolId == rhs.poolId
    }
}
