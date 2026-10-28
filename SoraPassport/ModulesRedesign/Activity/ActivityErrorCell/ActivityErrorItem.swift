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

/// A row with one line of text and a Refresh button.
final class ActivityErrorItem: ItemProtocol {

    /// The text above the button. `nil`: "Some data is not up to date".
    let title: String?
    /// The row is the top of the list's card and has its rounded corners.
    /// Not so for a row at the end of the list.
    let roundsTop: Bool
    var handler: (() -> Void)?

    init(title: String? = nil, roundsTop: Bool = true) {
        self.title = title
        self.roundsTop = roundsTop
    }
}

extension ActivityErrorItem: Hashable {
    static func == (lhs: ActivityErrorItem, rhs: ActivityErrorItem) -> Bool {
        return lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

/// A calm, non-interactive note shown above the activity list, for example
/// when the indexer can list only operations this account signed.
final class ActivityNoticeItem: ItemProtocol {
    let text: String
    /// The row is the top of the list's card and has its rounded corners.
    let roundsTop: Bool

    init(text: String, roundsTop: Bool = true) {
        self.text = text
        self.roundsTop = roundsTop
    }
}

extension ActivityNoticeItem: Hashable {
    static func == (lhs: ActivityNoticeItem, rhs: ActivityNoticeItem) -> Bool {
        return lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
