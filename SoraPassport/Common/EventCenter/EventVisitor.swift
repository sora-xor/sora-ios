// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

protocol EventVisitorProtocol: AnyObject {
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
    func processNewTransactionCreated(event: NewTransactionCreatedEvent)
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
    func processExtricsicSubmmited(event: ExtricsicSubmittedEvent)
    func processLanguageChanged(event: LanguageChanged)
    func processAccountBackuped(event: AccountBackuped)
    func processNewBlockAppeared(event: NewBlockEvent)

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
    func processNewTransactionCreated(event: NewTransactionCreatedEvent) {}
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
    
    func processExtricsicSubmmited(event: ExtricsicSubmittedEvent) {}

    func processLanguageChanged(event: LanguageChanged) {}
    
    func processAccountBackuped(event: AccountBackuped) {}

    func processNewBlockAppeared(event: NewBlockEvent) {}
    
//    func processUserInactive(event _: UserInactiveEvent) {}
}
