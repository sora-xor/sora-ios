/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

typealias NetworkBoolResultCompletionBlock = (Result<Bool, Error>?) -> Void
typealias NetworkProjectCompletionBlock = (Result<[ProjectData], Error>?) -> Void
typealias NetworkReferendumCompletionBlock = (Result<[ReferendumData], Error>?) -> Void
typealias NetworkProjectDetailsCompletionBlock = (Result<ProjectDetailsData?, Error>?) -> Void
typealias NetworkReferendumDetailsCompletionBlock = (Result<ReferendumData?, Error>?) -> Void
typealias NetworkUserCompletionBlock = (Result<UserData?, Error>?) -> Void
typealias NetworkFetchVotesCompletionBlock = (Result<VotesData?, Error>?) -> Void
typealias NetworkFetchInvitedCompletionBlock = (Result<ActivatedInvitationsData?, Error>?) -> Void
typealias NetworkCheckInvitationCompletionBlock = (Result<InvitationCheckData, Error>?) -> Void
typealias NetworkReputationCompletionBlock = (Result<ReputationData?, Error>?) -> Void
typealias NetworkReputationDetailsCompletionBlock = (Result<ReputationDetailsData?, Error>?) -> Void
typealias NetworkVotesHistoryCompletionBlock = (Result<[VotesHistoryEventData]?, Error>?) -> Void
typealias NetworkActivityFeedCompletionBlock = (Result<ActivityData?, Error>?) -> Void
typealias NetworkAnnouncementCompletionBlock = (Result<AnnouncementData?, Error>?) -> Void
typealias NetworkHelpCompletionBlock = (Result<HelpData?, Error>?) -> Void
typealias NetworkCurrencyCompletionBlock = (Result<CurrencyData?, Error>?) -> Void
typealias NetworkSupportedVersionBlock = (Result<SupportedVersionData, Error>?) -> Void
typealias NetworkVerificationCodeCompletionBlock = (Result<VerificationCodeData, Error>?) -> Void
typealias NetworkCountryCompletionBlock = (Result<CountryData?, Error>?) -> Void
typealias NetworkEmptyCompletionBlock = (Result<Void, Error>?) -> Void

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

    func applyInvitation(code: String, runCompletionIn queue: DispatchQueue,
                         completionBlock: @escaping NetworkEmptyCompletionBlock) throws -> Operation

    func checkInvitation(for deviceInfo: DeviceInfo,
                         runCompletionIn queue: DispatchQueue,
                         completionBlock: @escaping NetworkCheckInvitationCompletionBlock) throws -> Operation

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
    func fetchAllProjects(with pagination: OffsetPagination, runCompletionIn queue: DispatchQueue,
                          completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation

    func fetchFavoriteProjects(with pagination: OffsetPagination, runCompletionIn queue: DispatchQueue,
                               completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation

    func fetchVotedProjects(with pagination: OffsetPagination, runCompletionIn queue: DispatchQueue,
                            completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation

    func fetchFinishedProjects(with pagination: OffsetPagination, runCompletionIn queue: DispatchQueue,
                               completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation

    func fetchOpenReferendums(runCompletionIn queue: DispatchQueue,
                              completionBlock: @escaping NetworkReferendumCompletionBlock) throws -> Operation

    func fetchVotedReferendums(runCompletionIn queue: DispatchQueue,
                               completionBlock: @escaping NetworkReferendumCompletionBlock) throws -> Operation

    func fetchFinishedReferendums(runCompletionIn queue: DispatchQueue,
                                  completionBlock: @escaping NetworkReferendumCompletionBlock) throws -> Operation

    func fetchProjectDetails(for projectId: String, runCompletionIn queue: DispatchQueue,
                             completionBlock: @escaping NetworkProjectDetailsCompletionBlock) throws -> Operation

    func fetchReferendumDetails(for referendumId: String, runCompletionIn queue: DispatchQueue,
                                completionBlock: @escaping NetworkReferendumDetailsCompletionBlock) throws -> Operation

    func toggleFavorite(projectId: String,
                        runCompletionIn queue: DispatchQueue,
                        completionBlock: @escaping NetworkBoolResultCompletionBlock) throws -> Operation

    func vote(with customerVote: ProjectVote,
              runCompletionIn queue: DispatchQueue,
              completionBlock: @escaping NetworkBoolResultCompletionBlock) throws -> Operation

    func vote(with customerVote: ReferendumVote,
              runCompletionIn queue: DispatchQueue,
              completionBlock: @escaping NetworkEmptyCompletionBlock) throws -> Operation

    func fetchVotes(runCompletionIn queue: DispatchQueue,
                    completionBlock: @escaping NetworkFetchVotesCompletionBlock) throws -> Operation

    func fetchVotesHistory(with info: OffsetPagination,
                           runCompletionIn queue: DispatchQueue,
                           completionBlock: @escaping NetworkVotesHistoryCompletionBlock) throws -> Operation

    func fetchActivityFeed(with info: OffsetPagination,
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
