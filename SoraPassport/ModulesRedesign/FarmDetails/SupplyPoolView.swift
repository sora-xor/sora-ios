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
import SnapKit

final class SupplyPoolView: SoramitsuView {
    
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

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func set(item: SupplyPoolItem?) {
        guard let item else { return }
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

    private func setupView() {
        addSubview(stackView)
        
        stackView.addArrangedSubviews([
            titleLabel,
            poolView,
            supplyLiquidity
        ])
    }

    private func setupConstraints() {
        stackView.snp.makeConstraints { make in
            make.leading.equalTo(self)
            make.top.centerX.centerY.equalTo(self)
        }
    }
}


