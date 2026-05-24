import BigInt
import Foundation
import SSFUtils

enum XcmWeightLimit: Codable {
    case unlimited
    case limited(weight: BigUInt)
    case limitedV3(weight: SpWeightsWeightV3Weight)

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .unlimited:
            try container.encode("Unlimited")
        case let .limited(weight):
            try container.encode("Limited")
            try container.encode(StringCodable(wrappedValue: weight))
        case let .limitedV3(weight):
            try container.encode("Limited")
            try container.encode(weight)
        }
    }

    init(from _: Decoder) throws {
        fatalError("Decoding unsupported")
    }
}

extension XcmWeightLimit: Equatable {
    static func == (lhs: XcmWeightLimit, rhs: XcmWeightLimit) -> Bool {
        switch (lhs, rhs) {
        case let (.limited(lhsValue), .limited(rhsValue)):
            return lhsValue == rhsValue
        case let (.limitedV3(lhsValue), .limitedV3(rhsValue)):
            return lhsValue == rhsValue
        case (.unlimited, .unlimited):
            return true
        default:
            return false
        }
    }
}
