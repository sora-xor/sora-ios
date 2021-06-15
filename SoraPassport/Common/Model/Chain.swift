import Foundation
import IrohaCrypto

typealias SNAddressType = UInt8

enum Chain: String, Codable, CaseIterable {
    case polkadot = "Polkadot"
    case sora = "Sora"
}
