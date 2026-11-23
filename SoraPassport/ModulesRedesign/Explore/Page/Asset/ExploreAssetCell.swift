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
        let placeholder: SoramitsuLoadingPlaceholderType = viewModel.assetId == nil && LitMotion.allowed ? .shimmer : .none
        assetView.assetImageView.sora.picture = viewModel.icon.map { .logo(image: $0) }
        assetView.assetImageView.sora.loadingPlaceholder.type = placeholder
        assetView.titleLabel.sora.text = viewModel.title
        assetView.titleLabel.sora.loadingPlaceholder.type = placeholder
        assetView.amountUpLabel.sora.text = viewModel.price
        assetView.amountUpLabel.sora.loadingPlaceholder.type = placeholder
        assetView.subtitleLabel.sora.text = viewModel.marketCap.value
        assetView.subtitleLabel.sora.loadingPlaceholder.type = placeholder
        assetView.amountDownLabel.sora.attributedText = viewModel.deltaPrice.value ?? nil
        assetView.amountDownLabel.sora.loadingPlaceholder.type = placeholder
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
