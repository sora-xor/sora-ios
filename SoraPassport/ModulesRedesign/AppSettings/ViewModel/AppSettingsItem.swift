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

import SoraUIKit

final class AppSettingsItem: NSObject {

    enum SwitcherState {
        case disabled
        case on
        case off
    }

    enum RightItem {
        case arrow
        case switcher(state: SwitcherState)
    }

    let title: String
    let picture: Picture?
    let rightItem: RightItem
    let onTap: (()->())?
    let onSwitch: ((Bool)->())?

    init(title: String, picture: Picture? = nil, rightItem: RightItem, onTap: (()->())? = nil, onSwitch: ((Bool)->())? = nil) {
        self.title = title
        self.picture = picture
        self.rightItem = rightItem
        self.onTap = onTap
        self.onSwitch = onSwitch
    }
}

extension AppSettingsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { AppSettingsCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        onTap?()
    }
}

/// One mutually exclusive appearance choice, stored in the existing theme key.
final class AppAppearanceItem: NSObject, SoramitsuTableViewItemProtocol {
    let title: String
    let choices: [String]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    init(title: String, choices: [String], selectedIndex: Int, onSelect: @escaping (Int) -> Void) {
        self.title = title
        self.choices = choices
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
    }

    var cellType: AnyClass { AppAppearanceCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }
    func itemActionTap(with context: SoramitsuTableViewContext?) {}
}
