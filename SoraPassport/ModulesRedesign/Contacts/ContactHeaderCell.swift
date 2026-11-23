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
import SSFUtils

final class ContactHeaderCell: SoramitsuTableViewCell {
    
    private let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.shadow = .small
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerMask = .top
        view.sora.cornerRadius = .max
        return view
    }()

    private let icon = UIImageView()
    private let row = UIStackView()

    private let accountTitle: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.headline4
        label.sora.numberOfLines = 2
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        sora.clipsToBounds = true
        contentView.addSubview(containerView)
        icon.tintColor = WalletUX.accent
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(icon)
        row.addArrangedSubview(accountTitle)
        containerView.addSubview(row)
        isAccessibilityElement = true
    }
    
    func setupConstraints() {
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            row.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            row.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            row.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
        ])
    }
}

extension ContactHeaderCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ContactHeaderCellItem else {
            return
        }
        accountTitle.sora.text = item.title
        icon.image = item.symbol.flatMap { UIImage(systemName: $0) }
        icon.isHidden = icon.image == nil
        containerView.sora.cornerMask = item.symbol == nil ? .top : .all
        accessibilityLabel = item.title
        accessibilityHint = item.onTap == nil ? nil : R.string.localizable.commonRetry(preferredLanguages: .currentLocale)
        accessibilityTraits = item.onTap != nil ? .button : (item.symbol == nil ? .header : .staticText)
    }
}
