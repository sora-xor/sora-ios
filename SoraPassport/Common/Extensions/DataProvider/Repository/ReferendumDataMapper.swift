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
