import Foundation
import FearlessUtils
import BigInt

struct BalanceDepositEvent: Decodable {
    let accountId: AccountAddress
    let amount: BigUInt

    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()

        accountId = try unkeyedContainer.decode(AccountAddress.self)
        amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
    }
}

struct FeeWithdrawn: Decodable {
    let assetId: AssetId
    @StringCodable var amount: BigUInt
    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()
        self.amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
        self.assetId = AssetId(wrappedValue: "0x000")
    }
}