/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

enum VotingListModel {
    case project(_ project: ProjectData)
    case referendum(_ referendum: ReferendumData)
}

extension VotingListModel: Identifiable {
    var identifier: String {
        switch self {
        case .project(let project):
            return project.identifier
        case .referendum(let referendum):
            return referendum.identifier
        }
    }

    var statusUpdateTime: Int64 {
        switch self {
        case .project(let project):
            return project.statusUpdateTime
        case .referendum(let referendum):
            return referendum.statusUpdateTime
        }
    }
}
