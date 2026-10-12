import Foundation

enum XcmVersionedMultiLocation: Codable {
    case V1(XcmV1MultiLocation)
    case V3(XcmV1MultiLocation)

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .V1(multilocation):
            try container.encode("V1")
            try container.encode(multilocation)
        case let .V3(multilocation):
            try container.encode("V3")
            try container.encode(multilocation)
        }
    }
}

extension XcmVersionedMultiLocation: Equatable {
    static func == (lhs: XcmVersionedMultiLocation, rhs: XcmVersionedMultiLocation) -> Bool {
        switch (lhs, rhs) {
        case let (.V1(lhsMultilocation), .V1(rhsMultilocation)):
            return lhsMultilocation == rhsMultilocation
        case let (.V3(lhsMultilocation), .V3(rhsMultilocation)):
            return lhsMultilocation == rhsMultilocation
        default:
            return false
        }
    }
}
