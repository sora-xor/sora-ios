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

import UIKit
import SoraUIKit
import SnapKit
import SoraFoundation

final class BackupCell: SoramitsuTableViewCell, SoramitsuTableViewCellProtocol {
    private let titleLabel = WalletUX.label(style: .headline)
    private let descriptionLabel = WalletUX.label(style: .subheadline)
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let text = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
        text.axis = .vertical
        text.spacing = 4
        let row = UIStackView(arrangedSubviews: [text, chevron])
        row.spacing = 16
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        chevron.tintColor = WalletUX.accent
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.isAccessibilityElement = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        titleLabel.text = R.string.localizable.backupNow(preferredLanguages: .currentLocale)
        descriptionLabel.text = R.string.localizable.protectLossAccessFunds(preferredLanguages: .currentLocale)
        accessibilityLabel = [titleLabel.text, descriptionLabel.text].compactMap { $0 }.joined(separator: ". ")
    }
}
