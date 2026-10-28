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
import RobinHood
import CoreData

extension CDRuntimeMetadataItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let item = try RuntimeMetadataItem(from: decoder)

        identifier = item.chain
        version = Int32(bitPattern: item.version)
        txVersion = Int32(bitPattern: item.txVersion)
        metadata = item.metadata
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: RuntimeMetadataItem.CodingKeys.self)

        try container.encode(identifier, forKey: .chain)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(UInt32(bitPattern: version), forKey: .version)
        try container.encode(UInt32(bitPattern: txVersion), forKey: .txVersion)
    }
}
