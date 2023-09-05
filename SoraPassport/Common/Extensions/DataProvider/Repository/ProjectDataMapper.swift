// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
