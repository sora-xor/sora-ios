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

final class ExploreAssetListCell: SoramitsuTableViewCell {

    private var assetItem: ExploreAssetListItem?

    private lazy var assetView: ExploreAssetView = {
        let view = ExploreAssetView()
        view.assetImageView.sora.loadingPlaceholder.type = .none
        view.titleLabel.sora.loadingPlaceholder.type = .none
        view.subtitleLabel.sora.loadingPlaceholder.type = .none
        view.amountUpLabel.sora.loadingPlaceholder.type = .none
        view.amountDownLabel.sora.loadingPlaceholder.type = .none
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

extension ExploreAssetListCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ExploreAssetListItem else {
            assertionFailure("Incorect type of item")
            return
        }

        assetItem = item
        
        assetView.serialNumber.sora.text = item.viewModel.serialNumber
        assetView.assetImageView.sora.picture = .logo(image: item.viewModel.icon ?? UIImage())
        assetView.titleLabel.sora.text = item.viewModel.title
        assetView.subtitleLabel.sora.text = item.viewModel.marketCap
        assetView.amountUpLabel.sora.text = item.viewModel.price
        assetView.amountDownLabel.sora.attributedText = item.viewModel.deltaPrice
    }
}

