import Foundation

protocol EventVisitorProtocol: class {
    func processPushNotification(event: PushNotificationEvent)
    func processProjectVote(event: ProjectVoteEvent)
    func processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent)
    func processProjectView(event: ProjectViewEvent)
    func processInvitationInput(event: InvitationInputEvent)
    func processInvitationApplied(event: InvitationAppliedEvent)
    func processWalletUpdate(event: WalletUpdateEvent)
    func processReferendumVote(event: ReferendumVoteEvent)
}

extension EventVisitorProtocol {
    func processPushNotification(event: PushNotificationEvent) {}
    func processProjectVote(event: ProjectVoteEvent) {}
    func processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent) {}
    func processProjectView(event: ProjectViewEvent) {}
    func processInvitationInput(event: InvitationInputEvent) {}
    func processInvitationApplied(event: InvitationAppliedEvent) {}
    func processWalletUpdate(event: WalletUpdateEvent) {}
    func processReferendumVote(event: ReferendumVoteEvent) {}
}
