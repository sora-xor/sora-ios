/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraCrypto

enum ProjectServiceType: String {
    case fetch
    case favorites
    case voted
    case finished
    case referendumsOpen
    case referendumsVoted
    case referendumsFinished
    case toggleFavorite
    case vote
    case referendumSupportVote
    case referendumUnsupportVote
    case votesCount
    case votesHistory
    case projectDetails
    case referendumDetails
    case customer
    case customerUpdate
    case register
    case createUser
    case applyInvitation
    case checkInvitation
    case fetchInvited
    case reputation
    case reputationDetails
    case activityFeed
    case smsSend
    case smsVerify
    case announcement
    case help
    case currency
    case supportedVersion
    case country
}

final class ProjectUnitService: BaseService, ProjectUnitServiceProtocol {
    private(set) var unit: ServiceUnit

    var requestSigner: DARequestSigner?

    private(set) lazy var operationFactory = ProjectOperationFactory()

    init(unit: ServiceUnit) {
        self.unit = unit
    }
}
