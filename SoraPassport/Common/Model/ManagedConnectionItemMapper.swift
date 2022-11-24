/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import CoreData
import IrohaCrypto

enum ManagedConnectionItemMapperError: Error {
    case invalidEntity
}

final class ManagedConnectionItemMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = ManagedConnectionItem
    typealias CoreDataEntity = CDConnectionItem

    var entityIdentifierFieldName: String {
        #keyPath(CoreDataEntity.identifier)
    }

    func populate(entity: CoreDataEntity,
                  from model: DataProviderModel,
                  using context: NSManagedObjectContext) throws {
        entity.identifier = model.url.absoluteString
        entity.title = model.title
        entity.networkType = Int16(model.type)
        entity.order = model.order
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        guard
            let identifier = entity.identifier,
            let url = URL(string: identifier),
            let title = entity.title else {
            throw ManagedConnectionItemMapperError.invalidEntity
        }
        let networkType = SNAddressType(UInt8(entity.networkType))
        return ManagedConnectionItem(title: title,
                                     url: url,
                                     type: networkType,
                                     order: entity.order)
    }
}
