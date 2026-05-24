import Foundation

public struct SoraAssetId: Codable, Equatable {
    @ArrayCodable public var value: String

    public init(wrappedValue: String) {
        value = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: Data].self)

        value = dict["code"]?.toHex(includePrefix: true) ?? "-"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        guard let bytes = try? Data(hexStringSSF: value).map({ StringCodable(wrappedValue: $0) }) else {
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Invalid encoding"
            )
            throw EncodingError.invalidValue(value, context)
        }
        try container.encode(["code": bytes])
    }
}
