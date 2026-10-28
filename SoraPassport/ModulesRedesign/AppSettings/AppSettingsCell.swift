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
import Anchorage
import SoraFoundation

class AppSettingsCell: SoramitsuTableViewCell {

    let menuItem: MenuItem = {
        let view = MenuItem(frame: .zero)
        view.sora.shadow = .default
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = true
        view.sora.backgroundColor = .custom(uiColor: .clear)
        return view
    }()
    
    private var localizationManager = LocalizationManager.shared

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupView() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.addSubview(menuItem)
    }

    func setupConstraints() {
        menuItem.leadingAnchor == contentView.leadingAnchor + 16
        menuItem.trailingAnchor == contentView.trailingAnchor - 16
        menuItem.topAnchor == contentView.topAnchor + 8
        menuItem.bottomAnchor == contentView.bottomAnchor - 8
    }
    
    private func updateSemantics() {
        let semanticContentAttribute: UISemanticContentAttribute = localizationManager.isRightToLeft ? .forceRightToLeft : .forceLeftToRight
        menuItem.semanticContentAttribute = semanticContentAttribute
    }
}

extension AppSettingsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AppSettingsItem else {
            return
        }

        menuItem.titleLabel.sora.text = item.title
        menuItem.leftImageView.sora.picture = item.picture

        switch item.rightItem {
        case .arrow:
            menuItem.addArrow()
        case .switcher(let state):
            menuItem.addSwitcher()
            menuItem.switcher.isEnabled = state != .disabled
            menuItem.switcher.isOn = state == .on
        }
        menuItem.onTap = item.onTap
        menuItem.onSwitch = item.onSwitch
        
        updateSemantics()
    }
}

