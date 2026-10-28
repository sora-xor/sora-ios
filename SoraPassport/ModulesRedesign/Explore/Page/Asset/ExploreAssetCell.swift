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

final class ExploreAssetCell: SoramitsuTableViewCell {
    
    private var localizationManager = LocalizationManager.shared
    
    private let assetView = ExploreAssetView()

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
    
    private func updateContent(with viewModel: ExploreAssetViewModel) {
        if let icon = viewModel.icon {
            assetView.assetImageView.sora.picture = .logo(image: icon)
            assetView.assetImageView.sora.loadingPlaceholder.type = .none
        }
        
        if let title = viewModel.title {
            assetView.titleLabel.sora.text = title
            assetView.titleLabel.sora.loadingPlaceholder.type = .none
        }
        
        if let marketCap = viewModel.marketCap.value {
            assetView.subtitleLabel.sora.text = marketCap
        }
        assetView.subtitleLabel.sora.loadingPlaceholder.type = viewModel.marketCap.shimmerType
        
        if let price = viewModel.price {
            assetView.amountUpLabel.sora.text = price
            assetView.amountUpLabel.sora.loadingPlaceholder.type = .none
        }
        
        if let delta = viewModel.deltaPrice.value {
            assetView.amountDownLabel.sora.attributedText = delta
        }
        assetView.amountDownLabel.sora.loadingPlaceholder.type = viewModel.deltaPrice.shimmerType
    }
}

extension ExploreAssetCell: CellProtocol {
    func set(item: ItemProtocol) {
        guard let item = item as? ExploreAssetItem else {
            assertionFailure("Incorect type of item")
            return
        }
        assetView.serialNumber.sora.text = item.serialNumber
        updateContent(with: item.assetViewModel)
    }
}
