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

extension CDPhishingItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let phishingItem = try PhishingItem(from: decoder)

        identifier = phishingItem.identifier
        source = phishingItem.source
        publicKey = phishingItem.publicKey
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PhishingItem.CodingKeys.self)

      try container.encode(source, forKey: .source)
      try container.encode(publicKey, forKey: .publicKey)
    }
}
