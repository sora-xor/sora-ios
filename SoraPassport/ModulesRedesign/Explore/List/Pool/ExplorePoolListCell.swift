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

final class ExplorePoolListCell: SoramitsuTableViewCell {

    private var poolItem: ExplorePoolListItem?

    private lazy var poolView = ExplorePoolView()

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
    
}

extension ExplorePoolListCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ExplorePoolListItem else {
            assertionFailure("Incorect type of item")
            return
        }

        poolItem = item
        
        poolView.serialNumber.sora.text = item.viewModel.serialNumber
        poolView.isUserInteractionEnabled = false
        poolView.firstCurrencyImageView.image = item.viewModel.baseAssetIcon
        poolView.firstCurrencyImageView.sora.loadingPlaceholder.type = .none
        
        poolView.secondCurrencyImageView.image = item.viewModel.targetAssetIcon
        poolView.secondCurrencyImageView.sora.loadingPlaceholder.type = .none

        if let title = item.viewModel.title {
            poolView.titleLabel.sora.text = title
            poolView.titleLabel.sora.loadingPlaceholder.type = .none
        }

        if let subtitle = item.viewModel.tvl {
            poolView.subtitleLabel.sora.text = subtitle
            poolView.subtitleLabel.sora.loadingPlaceholder.type = .none
        }

        if let price = item.viewModel.apy {
            poolView.amountUpLabel.sora.text = price
            poolView.amountUpLabel.sora.loadingPlaceholder.type = .none
        }
    }
}
