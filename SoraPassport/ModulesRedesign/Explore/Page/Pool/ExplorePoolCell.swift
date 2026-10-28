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

final class ExplorePoolCell: SoramitsuTableViewCell {
    
    private var localizationManager = LocalizationManager.shared
    
    private let poolView = ExplorePoolView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(poolView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            poolView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            poolView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            poolView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            poolView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
    
    private func updateContent(with viewModel: ExplorePoolViewModel) {
        if let baseAssetIcon = viewModel.baseAssetIcon {
            poolView.firstCurrencyImageView.sora.picture = .logo(image: baseAssetIcon)
            poolView.firstCurrencyImageView.sora.loadingPlaceholder.type = .none
        }

        if let targetAssetIcon = viewModel.targetAssetIcon {
            poolView.secondCurrencyImageView.sora.picture = .logo(image: targetAssetIcon)
            poolView.secondCurrencyImageView.sora.loadingPlaceholder.type = .none
        }
        
        // Cells are reused: a value that is still loading (`nil`) clears
        // what the previous pool left behind and shows the placeholder.
        poolView.titleLabel.sora.text = viewModel.title ?? ""
        poolView.titleLabel.sora.loadingPlaceholder.type = viewModel.title == nil ? .shimmer : .none

        poolView.subtitleLabel.sora.text = viewModel.tvl ?? ""
        poolView.subtitleLabel.sora.loadingPlaceholder.type = viewModel.tvl == nil ? .shimmer : .none

        poolView.amountUpLabel.sora.text = viewModel.apy ?? ""
        poolView.amountUpLabel.sora.loadingPlaceholder.type = viewModel.apy == nil ? .shimmer : .none
        // An empty rate means the APY read finished with nothing to show:
        // no empty pill. The label keeps its place in the layout.
        poolView.amountUpLabel.alpha = viewModel.apy?.isEmpty == true ? 0 : 1
    }
}

extension ExplorePoolCell: CellProtocol {
    func set(item: ItemProtocol) {
        guard let item = item as? ExplorePoolItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        poolView.serialNumber.sora.text = item.serialNumber
        updateContent(with: item.poolViewModel)
    }
}
