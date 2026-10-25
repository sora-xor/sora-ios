import BigInt
import MocksBasket
import SSFCrypto
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest

@testable import SSFStorageQueryKit

// TODO: - Transfer this model to staking package
struct ValidatorPrefs: Codable, Equatable {
    @StringCodable var commission: BigUInt
    let blocked: Bool
}
