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

final class WarningCell: SoramitsuTableViewCell {
    
    private lazy var containterView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .statusWarningContainer
        view.sora.borderWidth = 1
        view.sora.borderColor = .statusWarning
        view.sora.cornerRadius = .max
        return view
    }()
    
    public let contentLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphS
        label.sora.textColor = .statusWarning
        label.sora.alignment = .center
        label.sora.numberOfLines = 0
        label.sora.text = R.string.localizable.confirnSupplyLiquidityFirstProviderWarning(preferredLanguages: .currentLocale)
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(containterView)
        containterView.addSubview(contentLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containterView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containterView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containterView.topAnchor.constraint(equalTo: contentView.topAnchor),
            
            contentLabel.leadingAnchor.constraint(equalTo: containterView.leadingAnchor, constant: 16),
            contentLabel.centerYAnchor.constraint(equalTo: containterView.centerYAnchor),
            contentLabel.centerXAnchor.constraint(equalTo: containterView.centerXAnchor),
            contentLabel.topAnchor.constraint(equalTo: containterView.topAnchor, constant: 24),
        ])
    }
}

extension WarningCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? WarningItem else {
            assertionFailure("Incorect type of item")
            return
        }
    }
}

