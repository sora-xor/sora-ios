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

final class ReferendumDataMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = ReferendumData
    typealias CoreDataEntity = CDReferendum

    let domain: String
    var entityIdentifierFieldName: String {
        return #keyPath(CDReferendum.identifier)
    }

    init(domain: String) {
        self.domain = domain
    }

    func populate(entity: CDReferendum,
                  from model: ReferendumData,
                  using context: NSManagedObjectContext) throws {
        entity.identifier = model.identifier
        entity.name = model.name
        entity.shortDetails = model.shortDescription
        entity.fullDetails = model.detailedDescription
        entity.imageLink = model.imageLink?.absoluteString
        entity.fundingDeadline = model.fundingDeadline
        entity.status = model.status.rawValue
        entity.statusUpdateTime = model.statusUpdateTime
        entity.supportVotes = model.supportVotes
        entity.opposeVotes = model.opposeVotes
        entity.userSupportVotes = model.userSupportVotes
        entity.userOpposeVotes = model.userOpposeVotes
        entity.domain = domain
    }

    func transform(entity: CDReferendum) throws -> ReferendumData {
        var imageLink: URL?

        if let imageLinkValue = entity.imageLink {
            imageLink = URL(string: imageLinkValue)
        }

        return ReferendumData(identifier: entity.identifier!,
                              name: entity.name!,
                              shortDescription: entity.shortDetails!,
                              detailedDescription: entity.fullDetails!,
                              fundingDeadline: entity.fundingDeadline,
                              statusUpdateTime: entity.statusUpdateTime,
                              imageLink: imageLink,
                              status: ReferendumDataStatus(rawValue: entity.status!)!,
                              supportVotes: entity.supportVotes!,
                              opposeVotes: entity.opposeVotes!,
                              userSupportVotes: entity.userSupportVotes!,
                              userOpposeVotes: entity.userOpposeVotes!)
    }
}
