import Foundation

struct InvitationAppliedEvent: EventProtocol {
    let code: String

    func accept(visitor: EventVisitorProtocol) {
        visitor.processInvitationApplied(event: self)
    }
}
