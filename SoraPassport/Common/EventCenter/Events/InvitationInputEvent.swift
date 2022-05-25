import Foundation

struct InvitationInputEvent: EventProtocol {
    let code: String

    func accept(visitor: EventVisitorProtocol) {
        visitor.processInvitationInput(event: self)
    }
}
