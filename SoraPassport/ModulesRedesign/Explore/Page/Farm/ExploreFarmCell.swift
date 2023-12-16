// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
        farmView.serialNumber.sora.text = viewModel.serialNumber
        
        if let baseAssetIcon = viewModel.baseAssetIcon {
            farmView.firstCurrencyImageView.sora.picture = .logo(image: baseAssetIcon)
            farmView.firstCurrencyImageView.sora.loadingPlaceholder.type = .none
        }

        if let targetAssetIcon = viewModel.targetAssetIcon {
            farmView.secondCurrencyImageView.sora.picture = .logo(image: targetAssetIcon)
            farmView.secondCurrencyImageView.sora.loadingPlaceholder.type = .none
        }
        
        if let targetAssetIcon = viewModel.rewardAssetIcon {
            farmView.rewardImageView.sora.picture = .logo(image: targetAssetIcon)
            farmView.rewardImageView.sora.loadingPlaceholder.type = .none
        }
        
        if let title = viewModel.title {
            farmView.titleLabel.sora.text = title
            farmView.titleLabel.sora.loadingPlaceholder.type = .none
        }

        if let subtitle = viewModel.tvl {
            farmView.subtitleLabel.sora.text = subtitle
            farmView.subtitleLabel.sora.loadingPlaceholder.type = .none
        }

        if let apr = viewModel.apr {
            farmView.amountUpLabel.sora.text = apr
            farmView.amountUpLabel.sora.loadingPlaceholder.type = .none
        }
    }
}

extension ExploreFarmCell: CellProtocol {
    func set(item: ItemProtocol) {
        guard let item = item as? ExploreFarmItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        updateContent(with: item.farmViewModel)
    }
}
