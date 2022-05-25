import Foundation

protocol EventVisitorProtocol: class {
//    func processPushNotification(event: PushNotificationEvent)
    func processProjectVote(event: ProjectVoteEvent)
    func processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent)
    func processProjectView(event: ProjectViewEvent)
    func processInvitationInput(event: InvitationInputEvent)
    func processInvitationApplied(event: InvitationAppliedEvent)
    func processWalletUpdate(event: WalletUpdateEvent)
    func processReferendumVote(event: ReferendumVoteEvent)
    //
    func processSelectedAccountChanged(event: SelectedAccountChanged)
    func processSelectedUsernameChanged(event: SelectedUsernameChanged)
    func processSelectedConnectionChanged(event: SelectedConnectionChanged)
    func processBalanceChanged(event: WalletBalanceChanged)
    func processStakingChanged(event: WalletStakingInfoChanged)
    func processNewTransaction(event: WalletNewTransactionInserted)
//    func processPurchaseCompletion(event: PurchaseCompleted)
    func processTypeRegistryPrepared(event: TypeRegistryPrepared)
    func processMigration(event: MigrationEvent)
    func processSuccsessMigration(event: MigrationSuccsessEvent)
}

extension EventVisitorProtocol {
//    func processPushNotification(event: PushNotificationEvent) {}
    func processProjectVote(event: ProjectVoteEvent) {}
    func processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent) {}
    func processProjectView(event: ProjectViewEvent) {}
    func processInvitationInput(event: InvitationInputEvent) {}
    func processInvitationApplied(event: InvitationAppliedEvent) {}
    func processWalletUpdate(event: WalletUpdateEvent) {}
    func processReferendumVote(event: ReferendumVoteEvent) {}
    //
    func processSelectedAccountChanged(event: SelectedAccountChanged) {}
    func processSelectedConnectionChanged(event: SelectedConnectionChanged) {}
    func processBalanceChanged(event: WalletBalanceChanged) {}
    func processStakingChanged(event: WalletStakingInfoChanged) {}
    func processNewTransaction(event: WalletNewTransactionInserted) {}
    func processSelectedUsernameChanged(event: SelectedUsernameChanged) {}
    func processTypeRegistryPrepared(event: TypeRegistryPrepared) {}
    func processMigration(event: MigrationEvent) {}
    func processSuccsessMigration(event: MigrationSuccsessEvent) {}
//    func processPurchaseCompletion(event: PurchaseCompleted) {}
}
