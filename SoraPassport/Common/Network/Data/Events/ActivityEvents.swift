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

struct UnknownEventData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case type = "__type"
    }

    var type: String
}

struct FriendRegisteredEventData: Codable, Equatable {
    var issuedAt: Int64
    var userId: String
}

struct VotingRightsCreditedEventData: Codable, Equatable {
    var issuedAt: Int64
    var userId: String
    var votingRights: String
}

struct UserReputationChangedEventData: Codable, Equatable {
    var issuedAt: Int64
    var userId: String
    var reputation: String
}

struct UserRankChangedEventData: Codable, Equatable {
    var issuedAt: Int64
    var rank: UInt
    var totalRank: UInt
}

struct ProjectCreatedEventData: Codable, Equatable {
    var issuedAt: Int64
    var projectId: String
    var name: String
    var description: String
    var fundingTarget: String
    var fundingDeadline: Int64
    var projectLink: String
    var imageLink: String
}

struct ProjectFundedEventData: Codable, Equatable {
    var issuedAt: Int64
    var projectId: String
}

struct ProjectClosedEventData: Codable, Equatable {
    var issuedAt: Int64
    var projectId: String
}

struct ProjectUpdatedEventData: Codable, Equatable {
    var issuedAt: Int64
    var projectId: String
    var name: String?
    var description: String?
    var fundingTarget: String?
    var fundingDeadline: Int64?
    var projectLink: String?
    var imageLink: String?
}

struct XORRewardCreditedFromProjectEventData: Codable, Equatable {
    var issuedAt: Int64
    var userId: String
    var reward: String
    var projectId: String
}

struct SenderBannedEventData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case issuedAt
        case userId
        case bannedIds = "bannedDids"
    }

    var issuedAt: Int64
    var userId: String
    var bannedIds: Set<String>
}

struct PushTokenChangedEventData: Codable, Equatable {
    var issuedAt: Int64
    var userId: String
    var oldToken: String?
    var newToken: String
}

struct InvitationSentEventData: Codable, Equatable {
    var issuedAt: Int64
    var userId: String
    var invitationCode: String
}

struct SenderPermissionGrantedEventData: Codable, Equatable {
    var issuedAt: Int64
    var userId: String
    var grantedTo: Set<String>
}

struct FriendHasVotedEventData: Codable, Equatable {
    var issuedAt: Int64
    var userId: String
    var friendId: String
    var projectId: String
}

struct UserHasVotedEventData: Codable, Equatable {
    var issuedAt: Int64
    var userId: String
    var projectId: String
    var givenVotes: String
}

struct PotentialRewardCalculatedEventData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case issuedAt
        case userId
        case potentialReward = "potentialXOR"
    }

    var issuedAt: Int64
    var userId: String
    var potentialReward: String
}

struct XORTransferedEventData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case issuedAt
        case source = "sender"
        case destination = "receiver"
        case message
        case amount
    }

    var issuedAt: Int64
    var source: String
    var destination: String
    var message: String
    var amount: String
}

struct PushReceiverRegisteredEventData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case issuedAt
        case userId
        case decentralizedIdentifiers = "didsWhiteList"
        case pushTokens
    }

    var issuedAt: Int64
    var userId: String
    var decentralizedIdentifiers: Set<String>
    var pushTokens: [String]
}

struct PushTokensRemovedEventData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case issuedAt
        case userId
        case removedTokens = "deletedTokens"
    }

    var issuedAt: Int64
    var userId: String
    var removedTokens: Set<String>
}

struct UserRequestedProjectDetailsEventData: Codable, Equatable {
    var issuedAt: Int64
    var userId: String
    var projectId: String
}

struct UserAgentCheckedVersionEventData: Codable, Equatable {
    var issuedAt: Int64
    var userId: String
    var appVersion: String
    var platform: String
    var supported: Bool
}
