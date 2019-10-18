import Foundation

struct ProjectVoteEvent: EventProtocol {
    let details: ProjectVote

    func accept(visitor: EventVisitorProtocol) {
        visitor.processProjectVote(event: self)
    }
}
