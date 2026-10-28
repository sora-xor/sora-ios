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
import SoraUIKit

final class ActivitySection {
    var id = UUID()
    var date: String?
    var items: [ActivitySectionItem]
    
    init(date: String? = nil,
         items: [ActivitySectionItem]) {
        self.date = date
        self.items = items
    }
}

enum ActivitySectionItem: Hashable {
    case activity(ActivityItem)
    case error(ActivityErrorItem)
    case notice(ActivityNoticeItem)
    case space(SoramitsuTableViewSpacerItem)
}

extension ActivitySection: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(date)
        hasher.combine(items)
    }
    
    static func == (lhs: ActivitySection, rhs: ActivitySection) -> Bool {
        lhs.id == rhs.id && lhs.date == rhs.date && lhs.items == rhs.items
    }
}

extension ActivitySectionItem {
    var isActivity: Bool {
        if case .activity = self {
            return true
        }
        return false
    }
}
