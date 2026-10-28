import Foundation

extension ChainData: Codable {
    private enum Case: String {
        case none = "None"
        case raw
        case blakeTwo256 = "BlakeTwo256"
        case sha256 = "Sha256"
        case keccak256 = "Keccak256"
        case shaThree256 = "ShaThree256"

        static func from(rawValue: String) -> Case? {
            if rawValue.lowercased().contains("raw") {
                return .raw
            }

            return Case(rawValue: rawValue)
        }
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let typeString = try container.decode(String.self)
        guard let type = Case.from(rawValue: typeString) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unexpected type found: \(typeString)"
            )
        }

        if type == .none {
            self = .none
        } else {
            let data = try container.decode(Data.self)

            switch type {
            case .raw:
                self = .raw(data: data)
            case .blakeTwo256:
                self = .blakeTwo256(data: H256(value: data))
            case .sha256:
                self = .sha256(data: H256(value: data))
            case .keccak256:
                self = .keccak256(data: H256(value: data))
            case .shaThree256:
                self = .shaThree256(data: H256(value: data))
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "unexpected type found: \(type)"
                )
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .none:
            try container.encode(Case.none.rawValue)
        case let .raw(data):
            try container.encode(Case.raw.rawValue)
            try container.encode(data)
        case let .blakeTwo256(hash):
            try container.encode(Case.blakeTwo256.rawValue)
            try container.encode(hash.value)
        case let .sha256(hash):
            try container.encode(Case.sha256.rawValue)
            try container.encode(hash.value)
        case let .keccak256(hash):
            try container.encode(Case.keccak256.rawValue)
            try container.encode(hash.value)
        case let .shaThree256(hash):
            try container.encode(Case.shaThree256.rawValue)
            try container.encode(hash.value)
        }
    }
}
