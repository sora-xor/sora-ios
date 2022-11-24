/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol AvailableInvitationsViewModelProtocol {
}

struct AvailableInvitationsViewModel: AvailableInvitationsViewModelProtocol {
    var accountAddress: String
    var invitationCount: Decimal
    var bondedAmount: Decimal
    var delegate: AvailableInvitationsCellDelegate
}

extension AvailableInvitationsViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return AvailableInvitationsCell.reuseIdentifier
    }
}
