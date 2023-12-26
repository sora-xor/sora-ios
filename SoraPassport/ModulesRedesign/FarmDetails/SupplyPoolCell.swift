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
import SnapKit

final class SupplyPoolCell: SoramitsuTableViewCell {
    
    private var supplyItem: SupplyPoolItem?
    
    private lazy var stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.sora.backgroundColor = .bgSurface
        stackView.sora.cornerRadius = .max
        stackView.sora.shadow = .small
        stackView.spacing = 16
        stackView.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    private lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.requestSupplyLiquidity(preferredLanguages: .currentLocale)
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        return label
    }()
    
    private lazy var poolView: ExplorePoolView = {
        let view = ExplorePoolView()
        return view
    }()
    
    private lazy var supplyLiquidity: SoramitsuButton = {
        let attributedText = SoramitsuTextItem(text: R.string.localizable.commonSupplyLiquidityTitle(preferredLanguages: .currentLocale),
                                               fontData: FontType.buttonM,
                                               textColor: .additionalPolkaswap,
                                               alignment: .center)
        let button = SoramitsuButton()
        button.sora.attributedText = attributedText
        button.sora.backgroundColor = .additionalPolkaswapContainer
        button.sora.cornerRadius = .circle
        button.sora.horizontalOffset = 0
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.supplyItem?.onTap?()
        }
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(stackView)
        
        stackView.addArrangedSubviews([
            titleLabel,
            poolView,
            supplyLiquidity
        ])
    }

    private func setupConstraints() {
        stackView.snp.makeConstraints { make in
            make.leading.equalTo(contentView).offset(16)
            make.top.centerX.centerY.equalTo(contentView)
        }
    }
}

extension SupplyPoolCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? SupplyPoolItem else {
            assertionFailure("Incorect type of item")
            return
        }
        supplyItem = item

        poolView.serialNumber.sora.isHidden = true
        
        if let baseAssetIcon = item.poolViewModel.baseAssetIcon {
            poolView.firstCurrencyImageView.sora.picture = .logo(image: baseAssetIcon)
            poolView.firstCurrencyImageView.sora.loadingPlaceholder.type = .none
        }

        if let targetAssetIcon = item.poolViewModel.targetAssetIcon {
            poolView.secondCurrencyImageView.sora.picture = .logo(image: targetAssetIcon)
            poolView.secondCurrencyImageView.sora.loadingPlaceholder.type = .none
        }
        
        if let title = item.poolViewModel.title {
            poolView.titleLabel.sora.text = title
            poolView.titleLabel.sora.loadingPlaceholder.type = .none
        }

        if let subtitle = item.poolViewModel.tvl {
            poolView.subtitleLabel.sora.text = subtitle
            poolView.subtitleLabel.sora.loadingPlaceholder.type = .none
        }

        if let price = item.poolViewModel.apy {
            poolView.amountUpLabel.sora.text = price
            poolView.amountUpLabel.sora.loadingPlaceholder.type = .none
        }
    }
}


