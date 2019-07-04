/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

protocol ProjectFundingOperationFactoryProtocol {
    func fetchProjectsOperation(_ urlTemplate: String, pagination: Pagination) -> NetworkOperation<[ProjectData]>
    func fetchProjectDetailsOperation(_ urlTemplate: String, projectId: String) -> NetworkOperation<ProjectDetailsData>
    func toggleFavoriteOperation(_ urlTemplate: String, projectId: String) -> NetworkOperation<Bool>
    func voteOperation(_ urlTemplate: String, vote: ProjectVote) -> NetworkOperation<Bool>
    func fetchVotesOperation(_ urlTemplate: String) -> NetworkOperation<VotesData>
    func fetchVotesHistory(_ urlTemplate: String, with info: Pagination) -> NetworkOperation<[VotesHistoryEventData]>
}

protocol ProjectAccountOperationFactoryProtocol {
    func registrationOperation(_ urlTemplate: String, with info: RegistrationInfo) -> NetworkOperation<Bool>
    func fetchCustomerOperation(_ urlTemplate: String) -> NetworkOperation<UserData>
    func updateCustomerOperation(_ urlTemplate: String, info: PersonalInfo) -> NetworkOperation<Bool>
    func checkInvitationOperation(_ urlTemplate: String, code: String) -> NetworkOperation<ApplicationFormData?>
    func fetchInvitationCodeOperation(_ urlTemplate: String) -> NetworkOperation<InvitationCodeData>
    func markAsUsedOperation(_ urlTemplate: String, invitationCode: String) -> NetworkOperation<Bool>
    func fetchActivatedInvitationsOperation(_ urlTemplate: String) -> NetworkOperation<ActivatedInvitationsData>
    func fetchReputationOperation(_ urlTemplate: String) -> NetworkOperation<ReputationData>
    func fetchActivityFeedOperation(_ urlTemplate: String,
                                    with page: Pagination) -> NetworkOperation<ActivityData>
    func sendSmsCodeOperation(_ urlTemplate: String) -> NetworkOperation<VerificationCodeData>
    func verifySmsCodeOperation(_ urlTemplate: String, code: String) -> NetworkOperation<Bool>
}

protocol ProjectInformationOperationFactoryProtocol {
    func fetchAnnouncement(_ urlTemplate: String) -> NetworkOperation<AnnouncementData?>
    func fetchHelp(_ urlTemplate: String) -> NetworkOperation<HelpData>
    func fetchCurrency(_ urlTemplate: String) -> NetworkOperation<CurrencyData>
}

final class ProjectOperationFactory {}
