import Foundation
import SSFModels
import SSFUtils

struct AccountId32Value: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case network
        case accountId = "id"
    }

    let network: XcmJunctionNetworkId
    @BytesCodable var accountId: AccountId
}

struct AccountId20Value: Codable, Equatable {
    let network: XcmJunctionNetworkId
    @BytesCodable var key: AccountId
}

struct AccountIndexValue: Codable, Equatable {
    let network: XcmJunctionNetworkId
    @StringCodable var index: UInt64
}
