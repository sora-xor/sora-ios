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

final class ProjectDataMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = ProjectData
    typealias CoreDataEntity = CDProject

    let domain: String
    var entityIdentifierFieldName: String {
        return #keyPath(CDProject.identifier)
    }

    init(domain: String) {
        self.domain = domain
    }

    func populate(entity: CDProject,
                  from model: ProjectData,
                  using context: NSManagedObjectContext) throws {
        entity.identifier = model.identifier
        entity.favorite = model.favorite
        entity.favoriteCount = model.favoriteCount
        entity.unwatched = model.unwatched
        entity.name = model.name
        entity.projectDescription = model.description
        entity.imageLink = model.imageLink?.absoluteString
        entity.link = model.link?.absoluteString
        entity.fundingTarget = model.fundingTarget
        entity.fundingCurrent = model.fundingCurrent
        entity.fundingDeadline = model.fundingDeadline
        entity.status = model.status.rawValue
        entity.statusUpdateTime = NSNumber(value: model.statusUpdateTime)
        entity.votedFriendsCount = model.votedFriendsCount
        entity.votes = model.votes

        entity.domain = domain
    }

    func transform(entity: CDProject) throws -> ProjectData {
        var imageLink: URL?

        if let imageLinkValue = entity.imageLink {
            imageLink = URL(string: imageLinkValue)
        }

        var link: URL?

        if let linkValue = entity.link {
            link = URL(string: linkValue)
        }

        return ProjectData(identifier: entity.identifier!,
                           favorite: entity.favorite,
                           favoriteCount: entity.favoriteCount,
                           unwatched: entity.unwatched,
                           name: entity.name!,
                           description: entity.projectDescription!,
                           imageLink: imageLink,
                           link: link,
                           fundingTarget: entity.fundingTarget!,
                           fundingCurrent: entity.fundingCurrent!,
                           fundingDeadline: entity.fundingDeadline,
                           status: ProjectDataStatus(rawValue: entity.status!)!,
                           statusUpdateTime: entity.statusUpdateTime!.int64Value,
                           votedFriendsCount: entity.votedFriendsCount,
                           votes: entity.votes!)
    }
}
