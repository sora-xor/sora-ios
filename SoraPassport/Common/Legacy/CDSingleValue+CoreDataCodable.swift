/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import CoreData
import RobinHood

extension CDCWSingleValue: CoreDataCodable {
    enum CodingKeys: String, CodingKey {
        case identifier
        case payload
    }

    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        payload = try container.decode(Data.self, forKey: .payload)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(identifier, forKey: .identifier)
        try container.encode(payload, forKey: .payload)
    }
}
