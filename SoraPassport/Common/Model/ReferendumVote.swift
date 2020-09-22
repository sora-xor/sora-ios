import Foundation

enum ReferendumVotingCase: Int, Encodable {
    case support
    case unsupport
}

struct ReferendumVote: Encodable {
    let referendumId: String
    let votes: String
    let votingCase: ReferendumVotingCase
}
