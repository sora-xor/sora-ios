import Foundation
import FearlessUtils
import BigInt

struct SoraTransferCall: Codable {
    let receiver: String
    @StringCodable var amount: BigUInt
    @ArrayCodable var assetId: String

    enum CodingKeys: String, CodingKey {
        case receiver = "to"
        case assetId = "asset_id"
        case amount = "amount"
    }
}


@propertyWrapper
public struct ArrayCodable: Codable, Equatable {
    public var wrappedValue: String

    public init(wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let byteArray = try container.decode([StringScaleMapper<UInt8>].self)
        let value = byteArray.reduce("0x") { $0 + String(format: "%02x", $1.value) }

        wrappedValue = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        guard let bytes = try? Data(hexString: wrappedValue).map({ StringScaleMapper(value: $0) }) else {
            let context = EncodingError.Context(codingPath: container.codingPath,
                                                debugDescription: "Invalid encoding")
            throw EncodingError.invalidValue(wrappedValue, context)
        }

        try container.encode(bytes)
    }
}
