/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

extension CDProject: CoreDataCodable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case favorite
        case favoriteCount
        case unwatched
        case name
        case projectDescription = "description"
        case imageLink
        case link = "projectLink"
        case fundingTarget
        case fundingCurrent
        case fundingDeadline
        case status
        case statusUpdateTime
        case votedFriendsCount
        case votes
    }

    public func populate(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        favorite = try container.decode(Bool.self, forKey: .favorite)
        favoriteCount = try container.decode(Int32.self, forKey: .favoriteCount)
        unwatched = try container.decode(Bool.self, forKey: .unwatched)
        name = try container.decode(String.self, forKey: .name)
        projectDescription = try container.decodeIfPresent(String.self,
                                                           forKey: .projectDescription)
        imageLink = try container.decodeIfPresent(String.self,
                                                  forKey: .imageLink)
        link = try container.decodeIfPresent(String.self,
                                             forKey: .link)
        fundingTarget = try container.decode(String.self, forKey: .fundingTarget)
        fundingCurrent = try container.decode(String.self, forKey: .fundingCurrent)
        fundingDeadline = try container.decode(Int64.self, forKey: .fundingDeadline)
        status = try container.decode(String.self, forKey: .status)

        if let optionalTime = try container.decodeIfPresent(Int64.self, forKey: .statusUpdateTime) {
            statusUpdateTime = NSNumber(value: optionalTime)
        }

        votedFriendsCount = try container.decode(Int32.self, forKey: .votedFriendsCount)
        votes = try container.decode(String.self, forKey: .votes)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(identifier, forKey: .identifier)
        try container.encode(favorite, forKey: .favorite)
        try container.encode(favoriteCount, forKey: .favoriteCount)
        try container.encode(unwatched, forKey: .unwatched)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(projectDescription, forKey: .projectDescription)
        try container.encodeIfPresent(imageLink, forKey: .imageLink)
        try container.encodeIfPresent(link, forKey: .link)
        try container.encode(fundingTarget, forKey: .fundingTarget)
        try container.encode(fundingCurrent, forKey: .fundingCurrent)
        try container.encode(fundingDeadline, forKey: .fundingDeadline)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(statusUpdateTime?.int64Value, forKey: .statusUpdateTime)
        try container.encode(votedFriendsCount, forKey: .votedFriendsCount)
        try container.encode(votes, forKey: .votes)
    }
}
