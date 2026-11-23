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

final class ExploreFarmCell: SoramitsuTableViewCell {
    
    private var localizationManager = LocalizationManager.shared
    
    private let farmView = ExploreFarmView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(farmView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            farmView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            farmView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            farmView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            farmView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
    
    private func updateContent(with viewModel: ExploreFarmViewModel) {
        let placeholder: SoramitsuLoadingPlaceholderType = viewModel.farmId == nil && LitMotion.allowed ? .shimmer : .none
        farmView.firstCurrencyImageView.sora.picture = viewModel.baseAssetIcon.map { .logo(image: $0) }
        farmView.firstCurrencyImageView.sora.loadingPlaceholder.type = placeholder
        farmView.secondCurrencyImageView.sora.picture = viewModel.targetAssetIcon.map { .logo(image: $0) }
        farmView.secondCurrencyImageView.sora.loadingPlaceholder.type = placeholder
        farmView.rewardImageView.sora.picture = viewModel.rewardAssetIcon.map { .logo(image: $0) }
        farmView.rewardImageView.sora.loadingPlaceholder.type = placeholder
        farmView.titleLabel.sora.text = viewModel.title
        farmView.titleLabel.sora.loadingPlaceholder.type = placeholder
        farmView.subtitleLabel.sora.text = viewModel.tvl
        farmView.subtitleLabel.sora.loadingPlaceholder.type = placeholder
        farmView.amountUpLabel.sora.text = viewModel.apr
        farmView.amountUpLabel.sora.loadingPlaceholder.type = placeholder
    }
}

extension ExploreFarmCell: CellProtocol {
    func set(item: ItemProtocol) {
        guard let item = item as? ExploreFarmItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        farmView.serialNumber.sora.text = item.serialNumber
        updateContent(with: item.farmViewModel)
    }
}
