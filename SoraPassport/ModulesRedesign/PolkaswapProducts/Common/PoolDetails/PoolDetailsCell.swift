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
import Combine

final class PoolDetailsCell: SoramitsuTableViewCell {
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var poolDetailsItem: PoolDetailsItem? {
        didSet {
            guard let item = poolDetailsItem else { return }
            item.service?.tvlTextPublisher
                .receive(on: DispatchQueue.main)
                .removeDuplicates()
                .filter { !$0.isEmpty }
                .sink { [weak self] value in
                    self?.headerView.subtitleLabel.sora.text = value
                    self?.headerView.subtitleLabel.sora.loadingPlaceholder.type = .none
                }
                .store(in: &cancellables)

            item.service?.detailsPublisher
                .receive(on: DispatchQueue.main)
                .removeDuplicates()
                .dropFirst()
                .sink { [weak self] value in
                    self?.updateDetails(with: value)
                }
                .store(in: &cancellables)
        }
    }
    
    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        return view
    }()
    
    private let detailsStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        view.spacing = 14
        return view
    }()
    
    private let footerStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        view.spacing = 16
        return view
    }()
    
    private let headerView = {
        let view = PoolDetailsHeaderView()
        view.subtitleLabel.sora.loadingPlaceholder.type = .shimmer
        view.subtitleLabel.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return view
    }()

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
        contentView.addSubview(containerView)
        containerView.addSubviews(headerView, detailsStackView, footerStackView)
        footerStackView.addArrangedSubviews(supplyLiquidity, removeLiquidity, limitationLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            headerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            headerView.heightAnchor.constraint(equalToConstant: 40),
            
            detailsStackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            detailsStackView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            detailsStackView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 24),
            
            footerStackView.leadingAnchor.constraint(equalTo: detailsStackView.leadingAnchor),
            footerStackView.centerXAnchor.constraint(equalTo: detailsStackView.centerXAnchor),
            footerStackView.topAnchor.constraint(equalTo: detailsStackView.bottomAnchor, constant: 24),
            footerStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            
            supplyLiquidity.heightAnchor.constraint(equalToConstant: 56),
            removeLiquidity.heightAnchor.constraint(equalToConstant: 56),
        ])
    }
    
    func updateDetails(with details: [DetailViewModel]) {
        detailsStackView.arrangedSubviews.forEach { subview in
            detailsStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        let detailsViews = details.map { detailModel -> DetailView in
            let view = DetailView()

            view.assetImageView.sora.isHidden = detailModel.rewardAssetImage == nil
            view.assetImageView.image = detailModel.rewardAssetImage

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
            
            switch detailModel.type {
            case .casual:
                view.progressView.isHidden = true
            case .progress(let float):
                view.progressView.isHidden = false
                view.progressView.set(progressPercentage: float)
            }
            
            view.isShimmerHidden = detailModel.infoHandler == nil
            
            return view
        }
        
        detailsViews.enumerated().forEach { index, view in
            detailsStackView.addArrangedSubview(view)
            
            if index != detailsViews.count - 1 {
                let separatorView = SoramitsuView()
                separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
                separatorView.sora.backgroundColor = .bgPage
                detailsStackView.addArrangedSubview(separatorView)
            }
        }
    }
}

extension PoolDetailsCell: CellProtocol {
    func set(item: ItemProtocol) {
        guard let item = item as? PoolDetailsItem else {
            assertionFailure("Incorect type of item")
            return
        }

        poolDetailsItem = item

        updateDetails(with: item.detailsViewModels)
        
        removeLiquidity.sora.isEnabled = item.isRemoveLiquidityEnabled && item.isThereLiquidity
        
        let titleColor: SoramitsuColor = item.isRemoveLiquidityEnabled && item.isThereLiquidity ? .additionalPolkaswap : .fgTertiary
        removeLiquidity.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonRemove(preferredLanguages: .currentLocale),
                                                                fontData: FontType.buttonM ,
                                                                textColor: titleColor,
                                                                alignment: .center)
        removeLiquidity.sora.backgroundColor = item.isRemoveLiquidityEnabled && item.isThereLiquidity ? .additionalPolkaswapContainer : .bgSurfaceVariant

        headerView.titleLabel.sora.text = item.title

        if let typeImage = item.typeImage.image {
            headerView.typeImageView.sora.picture = .logo(image: typeImage)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let icon = RemoteSerializer.shared.image(with: item.firstAssetImage ?? "")
            DispatchQueue.main.async {
                self.headerView.firstCurrencyImageView.image = icon
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = RemoteSerializer.shared.image(with: item.secondAssetImage ?? "")
            DispatchQueue.main.async {
                self.headerView.secondCurrencyImageView.image = icon
            }
        }
    
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = RemoteSerializer.shared.image(with: item.rewardAssetImage ?? "")
            DispatchQueue.main.async {
                self.headerView.rewardImageView.image = icon
            }
        }

        limitationLabel.sora.isHidden = item.isRemoveLiquidityEnabled || !item.isThereLiquidity
    }
}

