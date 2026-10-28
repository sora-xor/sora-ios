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

final class PooledCell: SoramitsuTableViewCell {
    
    private var activityItem: PooledItem?
    private var localizationManager = LocalizationManager.shared

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        return label
    }()

    private let fullStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
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
        fullStackView.addArrangedSubviews(titleLabel)
        fullStackView.setCustomSpacing(16, after: titleLabel)
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
    }
}

extension PooledCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PooledItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        titleLabel.sora.text = R.string.localizable.assetDetailsYourPools(item.assetSymbol, preferredLanguages: .currentLocale)
        
        fullStackView.arrangedSubviews.filter { $0 is PoolView }.forEach { subview in
            fullStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        let poolViews = item.poolViewModels.map { poolModel -> PoolView in
            let poolView = PoolView(mode: .view)
            poolView.firstCurrencyImageView.sora.loadingPlaceholder.type = .none
            poolView.secondCurrencyImageView.sora.loadingPlaceholder.type = .none
            poolView.rewardImageView.sora.loadingPlaceholder.type = .none
            poolView.titleLabel.sora.loadingPlaceholder.type = .none
            poolView.subtitleLabel.sora.loadingPlaceholder.type = .none
            poolView.amountUpLabel.sora.loadingPlaceholder.type = .none
            poolView.sora.firstPoolImage = poolModel.baseAssetImage
            poolView.sora.secondPoolImage = poolModel.targetAssetImage
            poolView.sora.rewardTokenImage = poolModel.rewardAssetImage
            poolView.sora.titleText = poolModel.title
            poolView.sora.subtitleText = poolModel.subtitle
            poolView.sora.upAmountText = poolModel.fiatText
            poolView.amountDownLabel.sora.attributedText = poolModel.deltaArributedText
            poolView.sora.addHandler(for: .touchUpInside) {
                item.openPoolDetailsHandler?(poolModel.identifier)
            }
            poolView.isRightToLeft = localizationManager.isRightToLeft
            return poolView
        }

        fullStackView.addArrangedSubviews(poolViews)
        activityItem = item
        
        updateSemantics()
    }
}

