/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import CoreData
import IrohaCrypto

enum AccountItemMapperError: Error {
    case invalidEntity
}

final class AccountItemMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = AccountItem
    typealias CoreDataEntity = CDAccountItem

    var entityIdentifierFieldName: String {
        #keyPath(CoreDataEntity.identifier)
    }

    func populate(entity: CoreDataEntity,
                  from model: DataProviderModel,
                  using context: NSManagedObjectContext) throws {
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

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        guard
            let address = entity.identifier,
            let username = entity.username,
            let cryptoType = CryptoType(rawValue: UInt8(entity.cryptoType)),
            let publicKeyData = entity.publicKey else {
            throw AccountItemMapperError.invalidEntity
        }
        let networkType = SNAddressType(UInt8(entity.networkType))
        let realSettings = AccountSettings(visibleAssetIds: entity.settings?.visibleAssets as? [String],
                                           orderedAssetIds: entity.settings?.orderedAssets as? [String]) 
        return DataProviderModel(address: address,
                                 cryptoType: cryptoType,
                                 networkType: networkType,
                                 username: username,
                                 publicKeyData: publicKeyData,
                                 settings: realSettings,
                                 order: entity.order,
                                 isSelected: entity.isSelected)
    }
}
