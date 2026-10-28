// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import CoreData
import RobinHood

extension CDContactItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let contact = try ContactItem(from: decoder)

        identifier = contact.identifier
        peerAddress = contact.peerAddress
        peerName = contact.peerName
        targetAddress = contact.targetAddress
        updatedAt = contact.updatedAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ContactItem.CodingKeys.self)

        try container.encodeIfPresent(peerAddress, forKey: .peerAddress)
        try container.encodeIfPresent(peerName, forKey: .peerName)
        try container.encodeIfPresent(targetAddress, forKey: .targetAddress)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
