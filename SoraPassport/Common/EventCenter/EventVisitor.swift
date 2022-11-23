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
//    func processSelectedNodeUpdated(event: ChainsUpdatedEvent)
    func processBalanceChanged(event: WalletBalanceChanged)
    func processStakingChanged(event: WalletStakingInfoChanged)
    func processNewTransaction(event: WalletNewTransactionInserted)
//    func processPurchaseCompletion(event: PurchaseCompleted)
    func processTypeRegistryPrepared(event: TypeRegistryPrepared)
    func processMigration(event: MigrationEvent)
    func processSuccsessMigration(event: MigrationSuccsessEvent)

    func processChainSyncDidStart(event: ChainSyncDidStart)
    func processChainSyncDidComplete(event: ChainSyncDidComplete)
    func processChainSyncDidFail(event: ChainSyncDidFail)
    func processChainsUpdated(event: ChainsUpdatedEvent)
    func processFailedNodeConnection(event: FailedNodeConnectionEvent)

    func processRuntimeCommonTypesSyncCompleted(event: RuntimeCommonTypesSyncCompleted)
    func processRuntimeChainTypesSyncCompleted(event: RuntimeChainTypesSyncCompleted)
    func processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted)

    func processRuntimeCoderReady(event: RuntimeCoderCreated)
    func processRuntimeCoderCreationFailed(event: RuntimeCoderCreationFailed)

//    func processSelectedNodeUpdated(event: SelectedNodeChangedEvent)

//    func processUserInactive(event: UserInactiveEvent)

//    func processMetaAccountChanged(event: MetaAccountModelChangedEvent)
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
    func processBalanceChanged(event: WalletBalanceChanged) {}
    func processStakingChanged(event: WalletStakingInfoChanged) {}
    func processNewTransaction(event: WalletNewTransactionInserted) {}
    func processSelectedUsernameChanged(event: SelectedUsernameChanged) {}
    func processTypeRegistryPrepared(event: TypeRegistryPrepared) {}
    func processMigration(event: MigrationEvent) {}
    func processSuccsessMigration(event: MigrationSuccsessEvent) {}
//    func processPurchaseCompletion(event: PurchaseCompleted) {}

    func processChainSyncDidStart(event _: ChainSyncDidStart) {}
    func processChainSyncDidComplete(event _: ChainSyncDidComplete) {}
    func processChainSyncDidFail(event _: ChainSyncDidFail) {}
    func processChainsUpdated(event _: ChainsUpdatedEvent) {}
    func processFailedNodeConnection(event: FailedNodeConnectionEvent) {}

    func processRuntimeCommonTypesSyncCompleted(event _: RuntimeCommonTypesSyncCompleted) {}
    func processRuntimeChainTypesSyncCompleted(event _: RuntimeChainTypesSyncCompleted) {}
    func processRuntimeChainMetadataSyncCompleted(event _: RuntimeMetadataSyncCompleted) {}

    func processRuntimeCoderReady(event _: RuntimeCoderCreated) {}
    func processRuntimeCoderCreationFailed(event _: RuntimeCoderCreationFailed) {}

    func processSelectedNodeUpdated(event: SelectedNodeChangedEvent) {}

//    func processUserInactive(event _: UserInactiveEvent) {}
}
