import Foundation

enum XcmVersionedMultiAssets: Codable {
    case V1([XcmV1MultiAsset])
    case V3([XcmV1MultiAsset])

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .V1(multiassets):
            try container.encode("V1")
            try container.encode(multiassets)
        case let .V3(multiassets):
            try container.encode("V3")
            try container.encode(multiassets)
        }
    }
}

extension XcmVersionedMultiAssets: Equatable {
    static func == (lhs: XcmVersionedMultiAssets, rhs: XcmVersionedMultiAssets) -> Bool {
        switch (lhs, rhs) {
        case let (.V1(lhsValue), .V1(rhsValue)):
            return lhsValue == rhsValue
        case let (.V3(lhsValue), .V3(rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}
