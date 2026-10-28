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

final class AssetListCell: SoramitsuTableViewCell {

    private var assetItem: AssetListItem?
    private var localizationManager = LocalizationManager.shared

    private lazy var assetView: AssetView = {
        let view = AssetView(mode: .view)
        view.assetImageView.sora.loadingPlaceholder.type = .none
        view.titleLabel.sora.loadingPlaceholder.type = .none
        view.subtitleLabel.sora.loadingPlaceholder.type = .none
        view.amountUpLabel.sora.loadingPlaceholder.type = .none
        view.amountDownLabel.sora.loadingPlaceholder.type = .none
        view.sora.favoriteButtonImage = R.image.wallet.star()
        view.sora.unfavoriteButtonImage = R.image.wallet.unstar()
        view.sora.dragDropImage = R.image.wallet.burger()
        view.assetImageView.sora.loadingPlaceholder.type = .none
        view.titleLabel.sora.loadingPlaceholder.type = .none
        view.subtitleLabel.sora.loadingPlaceholder.type = .none
        view.amountUpLabel.sora.loadingPlaceholder.type = .none
        view.amountDownLabel.sora.loadingPlaceholder.type = .none
        view.favoriteButton.sora.associate(states: .pressed) { [weak self] g in
            guard let item = self?.assetItem else {
                return
            }
            
            if item.canFavorite {
                view.sora.isFavorite.toggle()
                self?.assetItem?.favoriteHandle?(item)
            }
        }
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
        contentView.addSubview(assetView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            assetView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            assetView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            assetView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            assetView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
    
}

extension AssetListCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AssetListItem else {
            assertionFailure("Incorect type of item")
            return
        }

        assetView.sora.firstAssetImage = item.assetViewModel.icon
        assetView.sora.titleText = item.assetViewModel.title
        assetView.sora.subtitleText = item.assetViewModel.subtitle
        assetView.sora.mode = item.assetViewModel.mode
        assetView.sora.isFavorite = item.assetInfo.visible
        assetView.sora.upAmountText = item.assetViewModel.fiatText
        assetView.dragDropImageView.isHidden = true
        assetView.amountDownLabel.sora.attributedText = item.assetViewModel.deltaPriceText
        
        assetView.favoriteButton.sora.isEnabled = item.canFavorite
        assetView.isRightToLeft = localizationManager.isRightToLeft
        
        assetItem = item
    }
}

