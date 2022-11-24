/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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
