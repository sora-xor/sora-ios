import Foundation

enum ActivityEventType: String, Codable {
    case invitationSent = "InvitationSent"
    case potentialRewardCalculated = "PotentialRewardCalculated"
    case projectCreated = "ProjectCreated"
    case projectFunded = "ProjectFunded"
    case projectUpdated = "ProjectUpdated"
    case projectClosed = "ProjectClosed"
    case friendRegistered = "FriendRegistered"
    case userReputationChanged = "UserReputationChanged"
    case userRankChanged = "UserRankChanged"
    case userRequestedProjectDetails = "UserRequestedProjectDetails"
    case userAgentCheckedVersion = "UserAgentCheckedVersion"
    case userVotedForProject = "UserVotedForProject"
    case votingRightsCredited = "VotingRightsCredited"
    case votedFriendAdded = "VotedFriendAdded"
    case xorTransferred = "XORBetweenUsersTransferred"
    case xorRewardCreditedFromProject = "XORRewardCreditedFromProject"
    case pushReceiverRegistered = "PushReceiverRegistered"
    case senderPermissionGranted = "SenderPermissionGranted"
    case senderBanned = "SenderBanned"
    case pushTokenChanged = "PushTokenChanged"
    case pushTokensDeleted = "PushTokensDeleted"
}

// swiftlint:disable cyclomatic_complexity function_body_length
enum ActivityOneOfEventData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case type
    }

    case friendRegistered(_ event: FriendRegisteredEventData)
    case votingRightsCredited(_ event: VotingRightsCreditedEventData)
    case userReputationChanged(_ event: UserReputationChangedEventData)
    case userRankChanged(_ event: UserRankChangedEventData)
    case projectCreated(_ event: ProjectCreatedEventData)
    case projectFunded(_ event: ProjectFundedEventData)
    case projectClosed(_ event: ProjectClosedEventData)
    case userRequestedProjectDetails(_ event: UserRequestedProjectDetailsEventData)
    case userAgentCheckedVersion(_ event: UserAgentCheckedVersionEventData)
    case xorRewardCreditedFromProject(_ event: XORRewardCreditedFromProjectEventData)
    case projectUpdated(_ event: ProjectUpdatedEventData)
    case pushTokenChanged(_ event: PushTokenChangedEventData)
    case invitationSent(_ event: InvitationSentEventData)
    case senderPermissionGranted(_ event: SenderPermissionGrantedEventData)
    case friendHasVoted(_ event: FriendHasVotedEventData)
    case userHasVoted(_ event: UserHasVotedEventData)
    case potentialRewardCalculated(_ event: PotentialRewardCalculatedEventData)
    case xorTransfered(_ event: XORTransferedEventData)
    case pushReceiverRegistered(_ event: PushReceiverRegisteredEventData)
    case pushTokensRemoved(_ event: PushTokensRemovedEventData)
    case senderBanned(_ event: SenderBannedEventData)
    case unknown(_ event: UnknownEventData)

    init(from decoder: Decoder) throws {
        if let unknownEvent = try? UnknownEventData(from: decoder) {
            self = .unknown(unknownEvent)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        let typeValue = try container.decode(String.self, forKey: .type)
        guard let type = ActivityEventType(rawValue: typeValue) else {
            let event = UnknownEventData(type: typeValue)
            self = .unknown(event)
            return
        }

        switch type {
        case .friendRegistered:
            let event = try FriendRegisteredEventData(from: decoder)
            self = .friendRegistered(event)
        case .votingRightsCredited:
            let event = try VotingRightsCreditedEventData(from: decoder)
            self = .votingRightsCredited(event)
        case .userReputationChanged:
            let event = try UserReputationChangedEventData(from: decoder)
            self = .userReputationChanged(event)
        case .userRankChanged:
            let event = try UserRankChangedEventData(from: decoder)
            self = .userRankChanged(event)
        case .projectCreated:
            let event = try ProjectCreatedEventData(from: decoder)
            self = .projectCreated(event)
        case .projectFunded:
            let event = try ProjectFundedEventData(from: decoder)
            self = .projectFunded(event)
        case .projectClosed:
            let event = try ProjectClosedEventData(from: decoder)
            self = .projectClosed(event)
        case .projectUpdated:
            let event = try ProjectUpdatedEventData(from: decoder)
            self = .projectUpdated(event)
        case .xorRewardCreditedFromProject:
            let event = try XORRewardCreditedFromProjectEventData(from: decoder)
            self = .xorRewardCreditedFromProject(event)
        case .pushTokenChanged:
            let event = try PushTokenChangedEventData(from: decoder)
            self = .pushTokenChanged(event)
        case .invitationSent:
            let event = try InvitationSentEventData(from: decoder)
            self = .invitationSent(event)
        case .senderPermissionGranted:
            let event = try SenderPermissionGrantedEventData(from: decoder)
            self = .senderPermissionGranted(event)
        case .votedFriendAdded:
            let event = try FriendHasVotedEventData(from: decoder)
            self = .friendHasVoted(event)
        case .userVotedForProject:
            let event = try UserHasVotedEventData(from: decoder)
            self = .userHasVoted(event)
        case .potentialRewardCalculated:
            let event = try PotentialRewardCalculatedEventData(from: decoder)
            self = .potentialRewardCalculated(event)
        case .xorTransferred:
            let event = try XORTransferedEventData(from: decoder)
            self = .xorTransfered(event)
        case .pushReceiverRegistered:
            let event = try PushReceiverRegisteredEventData(from: decoder)
            self = .pushReceiverRegistered(event)
        case .pushTokensDeleted:
            let event = try PushTokensRemovedEventData(from: decoder)
            self = .pushTokensRemoved(event)
        case .userRequestedProjectDetails:
            let event = try UserRequestedProjectDetailsEventData(from: decoder)
            self = .userRequestedProjectDetails(event)
        case .senderBanned:
            let event = try SenderBannedEventData(from: decoder)
            self = .senderBanned(event)
        case .userAgentCheckedVersion:
            let event = try UserAgentCheckedVersionEventData(from: decoder)
            self = .userAgentCheckedVersion(event)
        }
    }

    func encode(to encoder: Encoder) throws {
        var type: ActivityEventType?

        switch self {
        case .friendRegistered(let event):
            try event.encode(to: encoder)
            type = .friendRegistered
        case .friendHasVoted(let event):
            try event.encode(to: encoder)
            type = .votedFriendAdded
        case .invitationSent(let event):
            try event.encode(to: encoder)
            type = .invitationSent
        case .potentialRewardCalculated(let event):
            try event.encode(to: encoder)
            type = .potentialRewardCalculated
        case .projectClosed(let event):
            try event.encode(to: encoder)
            type = .projectClosed
        case .projectCreated(let event):
            try event.encode(to: encoder)
            type = .projectCreated
        case .projectFunded(let event):
            try event.encode(to: encoder)
            type = .projectFunded
        case .projectUpdated(let event):
            try event.encode(to: encoder)
            type = .projectUpdated
        case .pushReceiverRegistered(let event):
            try event.encode(to: encoder)
            type = .pushReceiverRegistered
        case .pushTokenChanged(let event):
            try event.encode(to: encoder)
            type = .pushTokenChanged
        case .pushTokensRemoved(let event):
            try event.encode(to: encoder)
            type = .pushTokensDeleted
        case .senderBanned(let event):
            try event.encode(to: encoder)
            type = .senderBanned
        case .senderPermissionGranted(let event):
            try event.encode(to: encoder)
            type = .senderPermissionGranted
        case .userAgentCheckedVersion(let event):
            try event.encode(to: encoder)
            type = .userAgentCheckedVersion
        case .userHasVoted(let event):
            try event.encode(to: encoder)
            type = .userVotedForProject
        case .userReputationChanged(let event):
            try event.encode(to: encoder)
            type = .userReputationChanged
        case .userRankChanged(let event):
            try event.encode(to: encoder)
            type = .userRankChanged
        case .userRequestedProjectDetails(let event):
            try event.encode(to: encoder)
            type = .userRequestedProjectDetails
        case .votingRightsCredited(let event):
            try event.encode(to: encoder)
            type = .votingRightsCredited
        case .xorRewardCreditedFromProject(let event):
            try event.encode(to: encoder)
            type = .xorRewardCreditedFromProject
        case .xorTransfered(let event):
            try event.encode(to: encoder)
            type = .xorTransferred
        case .unknown(let event):
            try event.encode(to: encoder)
        }

        if let type = type {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
        }
    }
}
// swiftlint:enable cyclomatic_complexity function_body_length
