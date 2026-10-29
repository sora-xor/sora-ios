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
import IrohaCrypto

enum ChainNodeMapperError: Error {
    case missedRequiredFields
    case notSupported
}

final class ChainNodeModelMapper: CoreDataMapperProtocol {
    func transform(entity: CDChainNode) throws -> ChainNodeModel {
        guard let url = entity.url,
              let name = entity.name else {
            throw ChainNodeMapperError.missedRequiredFields
        }

        let apiKey: ChainNodeModel.ApiKey?
        if let queryName = entity.apiQueryName, let keyName = entity.apiKeyName {
            apiKey = .init(queryName: queryName, keyName: keyName)
        } else {
            apiKey = nil
        }

        return ChainNodeModel(
            url: url,
            name: name,
            apikey: apiKey
        )
    }

    func populate(entity: CDChainNode, from model: ChainNodeModel, using _: NSManagedObjectContext) throws {
        entity.name = model.name
        entity.url = model.url
        entity.apiKeyName = model.apikey?.keyName
        entity.apiQueryName = model.apikey?.queryName
    }

    var entityIdentifierFieldName: String { "url.absoluteString" }

    typealias DataProviderModel = ChainNodeModel

    typealias CoreDataEntity = CDChainNode
}
