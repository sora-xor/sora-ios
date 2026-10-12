import Foundation
import SSFModels
import SSFUtils

enum XcmJunctionNetworkId: Codable {
    case any
    case named(_ data: Data)
    case polkadot
    case kusama
    case westend
    case rococo
    case ethereum

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .any:
            try container.encode("Any")
            try container.encode(JSON.null)
        case let .named(data):
            try container.encode("Named")
            try container.encode(BytesCodable(wrappedValue: data))
        case .polkadot:
            try container.encode("Polkadot")
            try container.encode(JSON.null)
        case .kusama:
            try container.encode("Kusama")
            try container.encode(JSON.null)
        case .westend:
            try container.encode("Westend")
            try container.encode(JSON.null)
        case .rococo:
            try container.encode("Rococo")
            try container.encode(JSON.null)
        case .ethereum:
            try container.encode("Ethereum")
            try container.encode(JSON.null)
        }
    }

    static func from(ecosystem: ChainEcosystem) -> XcmJunctionNetworkId {
        switch ecosystem {
        case .kusama:
            return .kusama
        case .polkadot:
            return .polkadot
        case .westend:
            return .westend
        case .unknown:
            return .any
        case .rococo:
            return .rococo
        case .ethereum:
            return .ethereum
        }
    }
}

extension XcmJunctionNetworkId: Equatable {}
