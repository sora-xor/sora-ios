import Foundation

enum VoteDataError: Error {
    case projectNotFound
    case votingNotAllowed
    case votesNotEnough
    case incorrectVotesFormat

    static func error(from status: StatusData) -> VoteDataError? {
        switch status.code {
        case "PROJECT_NOT_FOUND":
            return .projectNotFound
        case "VOTING_NOT_ALLOWED":
            return .votingNotAllowed
        case "VOTES_NOT_ENOUGH":
            return .votesNotEnough
        case "INCORRECT_VOTES_VALUE_FORMAT":
            return .incorrectVotesFormat
        default:
            return nil
        }
    }
}

enum ReferendumVoteDataError: Error {
    case referendumNotFound
    case votingNotAllowed
    case votesNotEnough
    case userNotFound

    static func error(from status: StatusData) -> ReferendumVoteDataError? {
        switch status.code {
        case "REFERENDUM_NOT_FOUND":
            return .referendumNotFound
        case "VOTING_NOT_ALLOWED":
            return .votingNotAllowed
        case "VOTES_NOT_ENOUGH":
            return .votesNotEnough
        case "USER_NOT_FOUND":
            return .userNotFound
        default:
            return nil
        }
    }
}

enum ProjectFavoriteToggleDataError: Error {
    case projectNotFound
    case userNotFound

    static func error(from status: StatusData) -> ProjectFavoriteToggleDataError? {
        switch status.code {
        case "PROJECT_NOT_FOUND":
            return .projectNotFound
        case "USER_NOT_FOUND":
            return .userNotFound
        default:
            return nil
        }
    }
}

enum ProjectDetailsDataError: Error {
    case projectNotFound

    static func error(from status: StatusData) -> ProjectDetailsDataError? {
        switch status.code {
        case "PROJECT_NOT_FOUND":
            return .projectNotFound
        default:
            return nil
        }
    }
}
