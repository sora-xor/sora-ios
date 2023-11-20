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

final class PoolDetailsCell: SoramitsuTableViewCell {
    
    private var poolDetailsItem: PoolDetailsItem?
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.sora.shadow = .small
        view.spacing = 14
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()
    
    private lazy var headerView = PoolDetailsHeaderView()
    
    private lazy var supplyLiquidity: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.title = R.string.localizable.commonSupply(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .additionalPolkaswap
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.poolDetailsItem?.handler?(Liquidity.TransactionLiquidityType.add)
        }
        return button
    }()
    
    private lazy var removeLiquidity: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonRemove(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM ,
                                                       textColor: .additionalPolkaswap,
                                                       alignment: .center)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .additionalPolkaswapContainer
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.poolDetailsItem?.handler?(Liquidity.TransactionLiquidityType.withdraw)
        }
        return button
    }()
    
    public let limitationLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.text = R.string.localizable.polkaswapFarmingUnstakeToRemove(preferredLanguages: .currentLocale)
        label.sora.alignment = .center
        label.sora.numberOfLines = 0
        return label
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
        
        stackView.addArrangedSubviews(headerView)
        stackView.setCustomSpacing(24, after: headerView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}

extension PoolDetailsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PoolDetailsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        poolDetailsItem = item
        
        removeLiquidity.sora.isEnabled = item.isRemoveLiquidityEnabled && item.isThereLiquidity
        
        let titleColor: SoramitsuColor = item.isRemoveLiquidityEnabled && item.isThereLiquidity ? .additionalPolkaswap : .fgTertiary
        removeLiquidity.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonRemove(preferredLanguages: .currentLocale),
                                                                fontData: FontType.buttonM ,
                                                                textColor: titleColor,
                                                                alignment: .center)
        removeLiquidity.sora.backgroundColor = item.isRemoveLiquidityEnabled && item.isThereLiquidity ? .additionalPolkaswapContainer : .bgSurfaceVariant

        headerView.titleLabel.sora.text = item.title
        headerView.titleLabel.sora.loadingPlaceholder.type = item.title.isEmpty ? .shimmer : .none

        DispatchQueue.global(qos: .userInitiated).async {
            let icon = RemoteSerializer.shared.image(with: item.firstAssetImage ?? "")
            DispatchQueue.main.async {
                self.headerView.firstCurrencyImageView.image = icon
                self.headerView.firstCurrencyImageView.sora.loadingPlaceholder.type = icon == nil ? .shimmer : .none
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = RemoteSerializer.shared.image(with: item.secondAssetImage ?? "")
            DispatchQueue.main.async {
                self.headerView.secondCurrencyImageView.image = icon
                self.headerView.secondCurrencyImageView.sora.loadingPlaceholder.type = icon == nil ? .shimmer : .none
            }
        }
    
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = RemoteSerializer.shared.image(with: item.rewardAssetImage ?? "")
            DispatchQueue.main.async {
                self.headerView.rewardImageView.image = icon
                self.headerView.rewardImageView.sora.loadingPlaceholder.type = icon == nil ? .shimmer : .none
            }
        }

        stackView.arrangedSubviews.filter { $0 is DetailView || $0 is SoramitsuButton || $0 is SoramitsuView }.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        stackView.removeArrangedSubview(limitationLabel)
        
        let detailsViews = item.detailsViewModel.map { detailModel -> DetailView in
            let view = DetailView()

            view.assetImageView.sora.isHidden = detailModel.rewardAssetImage == nil
            DispatchQueue.global(qos: .userInitiated).async {
                let icon = RemoteSerializer.shared.image(with: detailModel.rewardAssetImage ?? "")
                DispatchQueue.main.async {
                    view.assetImageView.image = icon
                }
            }

            view.titleLabel.sora.text = detailModel.title
            view.titleLabel.sora.loadingPlaceholder.type = detailModel.title.isEmpty ? .shimmer : .none
            
            view.valueLabel.sora.attributedText = detailModel.assetAmountText
            view.valueLabel.sora.loadingPlaceholder.type = detailModel.assetAmountText.text.isEmpty ? .shimmer : .none
            
            view.fiatValueLabel.sora.attributedText = detailModel.fiatAmountText
            view.fiatValueLabel.sora.isHidden = detailModel.fiatAmountText == nil
            
            view.infoButton.sora.isHidden = detailModel.infoHandler == nil
            view.infoButton.sora.addHandler(for: .touchUpInside) { [weak detailModel] in
                detailModel?.infoHandler?()
            }
            
            view.isShimmerHidden = detailModel.infoHandler == nil
            
            return view
        }

        if let detailsView = detailsViews.first {
            stackView.setCustomSpacing(14, after: detailsView)
        }
        
        detailsViews.enumerated().forEach { index, view in
            stackView.addArrangedSubview(view)
            
            if index != detailsViews.count - 1 {
                let separatorView = SoramitsuView()
                separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
                separatorView.sora.backgroundColor = .bgPage
                stackView.addArrangedSubview(separatorView)
            }
        }
        
        
        if let assetView = detailsViews.last {
            stackView.setCustomSpacing(24, after: assetView)
        }

        stackView.addArrangedSubviews(supplyLiquidity, removeLiquidity)
        stackView.setCustomSpacing(16, after: supplyLiquidity)
        stackView.setCustomSpacing(16, after: removeLiquidity)
        
        stackView.addArrangedSubview(limitationLabel)
        limitationLabel.sora.isHidden = item.isRemoveLiquidityEnabled || !item.isThereLiquidity
    }
}

