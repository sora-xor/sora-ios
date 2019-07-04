/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraCrypto

enum ProjectServiceType: String {
    case fetch
    case favorites
    case voted
    case finished
    case toggleFavorite
    case vote
    case votesCount
    case votesHistory
    case projectDetails
    case customer
    case customerUpdate
    case checkInvitation
    case register
    case fetchInvitation
    case markInvitation
    case fetchInvited
    case reputation
    case activityFeed
    case smsSend
    case smsVerify
    case announcement
    case help
    case currency
}

final class ProjectUnitService: BaseService, ProjectUnitServiceProtocol {
    private(set) var unit: ServiceUnit

    var requestSigner: DARequestSigner?

    private(set) lazy var operationFactory = ProjectOperationFactory()

    init(unit: ServiceUnit) {
        self.unit = unit
    }
}
