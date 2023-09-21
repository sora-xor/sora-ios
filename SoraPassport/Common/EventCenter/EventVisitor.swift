// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
    
//    func processUserInactive(event _: UserInactiveEvent) {}
}
