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
