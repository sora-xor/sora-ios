import Foundation

enum XcmVersionedMultiAsset: Codable {
    case V1(XcmV1MultiAsset)
    case V3(XcmV1MultiAsset)

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .V1(multiasset):
            try container.encode("V1")
            try container.encode(multiasset)
        case let .V3(multiasset):
            try container.encode("V3")
            try container.encode(multiasset)
        }
    }
}

extension XcmVersionedMultiAsset: Equatable {
    static func == (lhs: XcmVersionedMultiAsset, rhs: XcmVersionedMultiAsset) -> Bool {
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
