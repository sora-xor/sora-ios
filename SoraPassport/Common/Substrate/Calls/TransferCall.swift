import Foundation
import FearlessUtils
import BigInt

struct SoraTransferCall: Codable {
    var receiver: MultiAddress
    @StringCodable var amount: BigUInt
    var assetId: AssetId

    enum CodingKeys: String, CodingKey {
        case receiver = "to"
        case assetId = "assetId"
        case amount = "amount"
    }
}

public enum SoraAddress: Equatable {
    case address32(_ value: Data)
}

extension SoraAddress: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let data = try container.decode(Data.self)
        self = .address32(data)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .address32(let value):
            try container.encode(value)
        }
    }
}

extension MultiAddress {
    var data: Data {
        switch self {
        case .accoundId(let value):
            return value
        case .accountTo(let value):
            return value
        case .accountIndex(let value):
            return value.serialize()
        case .raw(let value):
            return value
        case .address32(let value):
            return value
        case .address20(let value):
            return value
        }
    }
}

struct AssetId: Codable {
    @ArrayCodable var value: String

    public init(wrappedValue: String) {
        self.value = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: Data].self)

        value = dict["code"]?.toHex(includePrefix: true) ?? "-"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        guard let bytes = try? Data(hexString: value).map({ StringScaleMapper(value: $0) }) else {
            let context = EncodingError.Context(codingPath: container.codingPath,
                                                debugDescription: "Invalid encoding")
            throw EncodingError.invalidValue(value, context)
        }
        try container.encode(["code": bytes])
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
