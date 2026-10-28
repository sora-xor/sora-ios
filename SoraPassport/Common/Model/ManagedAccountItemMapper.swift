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

final class ManagedAccountItemMapper {
    var entityIdentifierFieldName: String { #keyPath(CoreDataEntity.identifier) }

    typealias DataProviderModel = ManagedAccountItem
    typealias CoreDataEntity = CDAccountItem

    private lazy var metaAccountMapper = AccountItemMapper()
}

extension ManagedAccountItemMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let metaAccount = try metaAccountMapper.transform(entity: entity)

        return DataProviderModel(
            address: metaAccount.address,
            cryptoType: metaAccount.cryptoType,
            networkType: metaAccount.networkType,
            username: metaAccount.username,
            publicKeyData: metaAccount.publicKeyData,
            order: metaAccount.order,
            settings: metaAccount.settings,
            isSelected: entity.isSelected
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext
    ) throws {
        entity.identifier = model.address
        entity.cryptoType = Int16(model.cryptoType.rawValue)
        entity.networkType = Int16(model.networkType)
        entity.publicKey = model.publicKeyData
        entity.username = model.username
        entity.order = model.order
        entity.isSelected = model.isSelected
        let cdSettings = CDAccountSettings(context: context)
        cdSettings.orderedAssets = model.settings.orderedAssetIds as NSArray?
        cdSettings.visibleAssets = model.settings.visibleAssetIds as NSArray?
        entity.settings = cdSettings
    }
}
