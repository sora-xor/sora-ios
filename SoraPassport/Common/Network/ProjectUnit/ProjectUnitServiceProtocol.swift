/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

typealias NetworkBoolResultCompletionBlock = (OperationResult<Bool>?) -> Void
typealias NetworkProjectCompletionBlock = (OperationResult<[ProjectData]>?) -> Void
typealias NetworkProjectDetailsCompletionBlock = (OperationResult<ProjectDetailsData>?) -> Void
typealias NetworkUserCompletionBlock = (OperationResult<UserData>?) -> Void
typealias NetworkFetchVotesCompletionBlock = (OperationResult<VotesData>?) -> Void
typealias NetworkFetchInviteCodeCompletionBlock = (OperationResult<InvitationCodeData>?) -> Void
typealias NetworkFetchInvitedCompletionBlock = (OperationResult<ActivatedInvitationsData>?) -> Void
typealias NetworkReputationCompletionBlock = (OperationResult<ReputationData>?) -> Void
typealias NetworkReputationDetailsCompletionBlock = (OperationResult<ReputationDetailsData>?) -> Void
typealias NetworkVotesHistoryCompletionBlock = (OperationResult<[VotesHistoryEventData]>?) -> Void
typealias NetworkActivityFeedCompletionBlock = (OperationResult<ActivityData>?) -> Void
typealias NetworkAnnouncementCompletionBlock = (OperationResult<AnnouncementData?>?) -> Void
typealias NetworkHelpCompletionBlock = (OperationResult<HelpData>?) -> Void
typealias NetworkCurrencyCompletionBlock = (OperationResult<CurrencyData>?) -> Void
typealias NetworkSupportedVersionBlock = (OperationResult<SupportedVersionData>?) -> Void
typealias NetworkVerificationCodeCompletionBlock = (OperationResult<VerificationCodeData>?) -> Void
typealias NetworkCountryCompletionBlock = (OperationResult<CountryData>?) -> Void

protocol ProjectUnitAccountProtocol {
    func registerCustomer(with info: RegistrationInfo,
                          runCompletionIn queue: DispatchQueue,
                          completionBlock: @escaping NetworkBoolResultCompletionBlock) throws -> Operation

    func createCustomer(with info: UserCreationInfo,
                        runCompletionIn queue: DispatchQueue,
                        completionBlock: @escaping NetworkVerificationCodeCompletionBlock) throws -> Operation

    func fetchCustomer(runCompletionIn queue: DispatchQueue,
                       completionBlock: @escaping NetworkUserCompletionBlock) throws -> Operation

    func updateCustomer(with info: PersonalInfo,
                        runCompletionIn queue: DispatchQueue,
                        completionBlock: @escaping NetworkBoolResultCompletionBlock) throws -> Operation

    func fetchInvitationCode(runCompletionIn queue: DispatchQueue,
                             completionBlock: @escaping NetworkFetchInviteCodeCompletionBlock) throws -> Operation

    func markAsUsed(invitationCode: String,
                    runCompletionIn queue: DispatchQueue,
                    completionBlock: @escaping NetworkBoolResultCompletionBlock) throws -> Operation

    func fetchActivatedInvitations(runCompletionIn queue: DispatchQueue,
                                   completionBlock: @escaping NetworkFetchInvitedCompletionBlock) throws -> Operation

    func fetchReputation(runCompletionIn queue: DispatchQueue,
                         completionBlock: @escaping NetworkReputationCompletionBlock) throws -> Operation

    func sendSmsCode(runCompletionIn queue: DispatchQueue,
                     completionBlock: @escaping NetworkVerificationCodeCompletionBlock) throws -> Operation

    func verifySms(codeInfo: VerificationCodeInfo, runCompletionIn queue: DispatchQueue,
                   completionBlock: @escaping NetworkBoolResultCompletionBlock) throws -> Operation
}

protocol ProjectUnitFundingProtocol {
    func fetchAllProjects(with pagination: Pagination, runCompletionIn queue: DispatchQueue,
                          completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation

    func fetchFavoriteProjects(with pagination: Pagination, runCompletionIn queue: DispatchQueue,
                               completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation

    func fetchVotedProjects(with pagination: Pagination, runCompletionIn queue: DispatchQueue,
                            completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation

    func fetchFinishedProjects(with pagination: Pagination, runCompletionIn queue: DispatchQueue,
                               completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation

    func fetchProjectDetails(for projectId: String, runCompletionIn queue: DispatchQueue,
                             completionBlock: @escaping NetworkProjectDetailsCompletionBlock) throws -> Operation

    func toggleFavorite(projectId: String,
                        runCompletionIn queue: DispatchQueue,
                        completionBlock: @escaping NetworkBoolResultCompletionBlock) throws -> Operation

    func vote(with customerVote: ProjectVote,
              runCompletionIn queue: DispatchQueue,
              completionBlock: @escaping NetworkBoolResultCompletionBlock) throws -> Operation

    func fetchVotes(runCompletionIn queue: DispatchQueue,
                    completionBlock: @escaping NetworkFetchVotesCompletionBlock) throws -> Operation

    func fetchVotesHistory(with info: Pagination,
                           runCompletionIn queue: DispatchQueue,
                           completionBlock: @escaping NetworkVotesHistoryCompletionBlock) throws -> Operation

    func fetchActivityFeed(with info: Pagination,
                           runCompletionIn queue: DispatchQueue,
                           completionBlock: @escaping NetworkActivityFeedCompletionBlock) throws -> Operation
}

protocol ProjectUnitInformationProtocol {
    func fetchAnnouncement(runCompletionIn queue: DispatchQueue,
                           completionBlock: @escaping NetworkAnnouncementCompletionBlock) throws -> Operation

    func fetchHelp(runCompletionIn queue: DispatchQueue,
                   completionBlock: @escaping NetworkHelpCompletionBlock) throws -> Operation

    func fetchReputationDetails(runCompletionIn queue: DispatchQueue,
                                completionBlock: @escaping NetworkReputationDetailsCompletionBlock) throws -> Operation

    func fetchCurrency(runCompletionIn queue: DispatchQueue,
                       completionBlock: @escaping NetworkCurrencyCompletionBlock) throws -> Operation

    func checkSupported(version: String,
                        runCompletionIn queue: DispatchQueue,
                        completionBlock: @escaping NetworkSupportedVersionBlock) throws -> Operation

    func fetchCountry(runCompletionIn queue: DispatchQueue,
                      completionBlock: @escaping NetworkCountryCompletionBlock) throws -> Operation
}

protocol ProjectUnitServiceProtocol: BaseServiceProtocol, ProjectUnitFundingProtocol,
ProjectUnitAccountProtocol, ProjectUnitInformationProtocol {}
