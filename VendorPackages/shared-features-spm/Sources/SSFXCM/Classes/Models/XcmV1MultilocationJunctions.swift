import Foundation
import SSFUtils

struct XcmV1MultilocationJunctions: Codable {
    let items: [XcmJunction]

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        if items.isEmpty {
            try container.encode("Here")
        } else {
            let xLocation = "X\(items.count)"
            try container.encode(xLocation)
        }

        if items.isEmpty {
            try container.encode(JSON.null)
        } else if items.count == 1 {
            try container.encode(items[0])
        } else {
            try container.encode(items)
        }
    }
}

extension XcmV1MultilocationJunctions: Equatable {}
