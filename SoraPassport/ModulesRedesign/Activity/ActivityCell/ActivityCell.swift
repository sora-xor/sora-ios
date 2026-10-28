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

final class ActivityCell: SoramitsuTableViewCell {

    private var assetItem: ActivityItem?
    private var localizationManager = LocalizationManager.shared

    private lazy var historyView: HistoryTransactionView = {
        let view = HistoryTransactionView()
        view.isUserInteractionEnabled = false
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
        contentView.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgSurface)
        contentView.addSubview(historyView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            historyView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            historyView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            historyView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            historyView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
}

extension ActivityCell: CellProtocol {
    func set(item: ItemProtocol) {
        guard let item = item as? ActivityItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        assetItem = item

        historyView.sora.firstHistoryTransactionImage  = item.model.firstAssetImageViewModel
        historyView.firstCurrencyImageView.sora.loadingPlaceholder.type = item.model.firstAssetImageViewModel != nil ? .none : .shimmer

        historyView.sora.secondHistoryTransactionImage = item.model.secondAssetImageViewModel
        historyView.secondCurrencyImageView.sora.loadingPlaceholder.type = item.model.firstAssetImageViewModel != nil ? .none : .shimmer

        historyView.sora.titleText = item.model.title
        historyView.titleLabel.sora.loadingPlaceholder.type = item.model.title.isEmpty ? .shimmer : .none
        
        historyView.sora.subtitleText = item.model.subtitle
        historyView.subtitleLabel.sora.loadingPlaceholder.type = item.model.subtitle.isEmpty ? .shimmer : .none
        
        historyView.sora.transactionType = item.model.typeTransactionImage
        historyView.transactionTypeImageView.sora.loadingPlaceholder.type = item.model.typeTransactionImage == nil ? .shimmer : .none
        
        historyView.sora.upAmountText = item.model.firstBalanceText
        historyView.amountUpLabel.sora.loadingPlaceholder.type = .none
        
        historyView.sora.fiatText = item.model.fiatText
        historyView.fiatLabel.sora.loadingPlaceholder.type = item.model.fiatText.isEmpty ? .shimmer : .none
        
        historyView.sora.isNeedTwoTokens = item.model.isNeedTwoImage
        historyView.oneCurrencyImageView.sora.loadingPlaceholder.type = item.model.isNeedTwoImage ? .shimmer : .none
        
        historyView.sora.statusImage = item.model.status.image
        historyView.statusImageView.sora.loadingPlaceholder.type = item.model.status.image == nil ? .shimmer : .none
        
        
        let defaultAlignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        let reversedAlignment: NSTextAlignment = localizationManager.isRightToLeft ? .left : .right
        historyView.amountUpLabel.sora.alignment = reversedAlignment
        historyView.titleLabel.sora.alignment = defaultAlignment
        historyView.subtitleLabel.sora.alignment = defaultAlignment
    }
}
