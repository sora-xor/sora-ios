import Foundation

struct ReferendumVoteEvent: EventProtocol {
    let vote: ReferendumVote

    func accept(visitor: EventVisitorProtocol) {
        visitor.processReferendumVote(event: self)
    }
}
