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
import SoraFoundation

final class AssetIdCell: SoramitsuTableViewCell {
    
    private let localizationManager = LocalizationManager.shared
    
    private let fullStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        view.spacing = 4
        return view
    }()
    
    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.text = R.string.localizable.walletAssetId(preferredLanguages: .currentLocale)
        return label
    }()
    
    private let assetIdLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphXS
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0 
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
        contentView.addSubview(fullStackView)
        fullStackView.addArrangedSubviews(titleLabel, assetIdLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            fullStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            fullStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            fullStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            fullStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
    
    private func updateSemantics() {
        let semanticContentAttribute: UISemanticContentAttribute = localizationManager.isRightToLeft ? .forceRightToLeft : .forceLeftToRight
        let alignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        fullStackView.semanticContentAttribute = semanticContentAttribute
        titleLabel.sora.alignment = alignment
        assetIdLabel.sora.alignment = alignment
    }
}

extension AssetIdCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AssetIdItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        assetIdLabel.sora.text = item.assetId
        
        updateSemantics()
    }
}

