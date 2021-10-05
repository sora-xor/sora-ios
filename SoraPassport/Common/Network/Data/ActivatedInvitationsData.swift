/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct ActivatedInvitationsData: Codable, Equatable {
    var invitedUsers: [InvitedUserData]
    var parentInfo: ParentInfoData?
}
