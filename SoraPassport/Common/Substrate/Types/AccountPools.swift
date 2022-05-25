import BigInt
import FearlessUtils

struct AccountPools: ScaleDecodable {
    let assetIds: [String]

    init(scaleDecoder: ScaleDecoding) throws {
        var assetIds: [String] = []
        // remove hex Prefix '0x'
        _ = try scaleDecoder.readAndConfirm(count: 1)
        for _ in 0 ..< (scaleDecoder.remained / 32) {
            let item = try scaleDecoder.readAndConfirm(count: 32)
            assetIds.append(item.toHex(includePrefix: true))
        }

        self.assetIds = assetIds
    }
}

struct PoolReserves: ScaleDecodable {
    let reserves: Balance
    let fees: Balance

    init(scaleDecoder: ScaleDecoding) throws {
        reserves = try Balance(scaleDecoder: scaleDecoder)
        fees = try Balance(scaleDecoder: scaleDecoder)
    }

    init(reserves: BigUInt = 0, fees: BigUInt = 0) {
        self.reserves = Balance(value: reserves)
        self.fees = Balance(value: fees)
    }
}

struct PoolProviders: ScaleDecodable {
    let reserves: Balance
    let fees: Balance

    init(scaleDecoder: ScaleDecoding) throws {
        reserves = try Balance(scaleDecoder: scaleDecoder)
        fees = try Balance(scaleDecoder: scaleDecoder)
    }

    init(reserves: BigUInt = 0, fees: BigUInt = 0) {
        self.reserves = Balance(value: reserves)
        self.fees = Balance(value: fees)
    }
}

struct PoolProperties: ScaleDecodable {
    let reservesAccountId: AccountId
    let feesAccountId: AccountId

    init(scaleDecoder: ScaleDecoding) throws {
        reservesAccountId = try AccountId(scaleDecoder: scaleDecoder)
        feesAccountId = try AccountId(scaleDecoder: scaleDecoder)
    }

    init(reservesAccountId: AccountId, feesAccountId: AccountId) {
        self.reservesAccountId = reservesAccountId
        self.feesAccountId = feesAccountId
    }
}

struct PoolDetails {
    let targetAsset: String
    let yourPoolShare: Double
    let sbAPYL: Double
    let xorPooled: Double
    let targetAssetPooled: Double
}
