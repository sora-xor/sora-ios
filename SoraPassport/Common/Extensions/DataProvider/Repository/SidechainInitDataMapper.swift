/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import CoreData

final class SidechainInitDataMapper<T: Codable>: CoreDataMapperProtocol {
    typealias DataProviderModel = SidechainInit<T>
    typealias CoreDataEntity = CDSidechainInit

    private lazy var jsonEncoder = JSONEncoder()
    private lazy var jsonDecoder = JSONDecoder()

    var entityIdentifierFieldName: String {
        #keyPath(CDSidechainInit.identifier)
    }

    func populate(entity: CDSidechainInit,
                  from model: SidechainInit<T>,
                  using context: NSManagedObjectContext) throws {
        entity.identifier = model.identifier
        entity.state = model.state.rawValue

        if let userInfo = model.userInfo {
            entity.userInfo = try jsonEncoder.encode(userInfo)
        }
    }

    func transform(entity: CDSidechainInit) throws -> SidechainInit<T> {
        var userInfo: T?

        if let userInfoData = entity.userInfo {
            userInfo = try jsonDecoder.decode(T.self, from: userInfoData)
        }

        return SidechainInit(sidechainId: SidechainId(rawValue: entity.identifier!)!,
                             state: SidechainInitState(rawValue: entity.state!)!,
                             userInfo: userInfo)
    }
}
