import Foundation

@propertyWrapper
public struct BytesCodable: Codable, Equatable {
    public var wrappedValue: String

    public init(wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let byteArray = try container.decode([StringScaleMapper<UInt8>].self)

        guard let value = String(data: Data(byteArray.map({ $0.value })), encoding: .utf8) else {
            throw DecodingError
            .dataCorrupted(.init(codingPath: container.codingPath, debugDescription: ""))
        }

        wrappedValue = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        guard let bytes = wrappedValue.data(using: .utf8)?.map({ StringScaleMapper(value: $0) }) else {
            let context = EncodingError.Context(codingPath: container.codingPath,
                                                debugDescription: "Invalid encoding")
            throw EncodingError.invalidValue(wrappedValue, context)
        }

        try container.encode(bytes)
    }
}
