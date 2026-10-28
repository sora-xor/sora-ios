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

final class FarmListCell: SoramitsuTableViewCell {
    private var farmListItem: FarmListItem?
    
    let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        return view
    }()
    
    public let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        view.spacing = 0
        return view
    }()
    
    public let footerLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.text = R.string.localizable.polkaswapFarmingDemeterPower(preferredLanguages: .currentLocale)
        label.sora.alignment = .center
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
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(stackView)
        containerView.addSubview(footerLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: stackView.topAnchor, constant: -24),
            
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            stackView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -16),
            
            footerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            footerLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            footerLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
    }
    
    func updateContent(with viewModels: [FarmViewModel]) {
        stackView.arrangedSubviews.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        let farmViews = viewModels.map { viewModel -> FarmView in
            let view = FarmView()
            
            if let baseAssetIcon = viewModel.baseAssetImage {
                view.firstCurrencyImageView.sora.picture = .logo(image: baseAssetIcon)
                view.firstCurrencyImageView.sora.loadingPlaceholder.type = .none
            }
            
            if let targetAssetIcon = viewModel.targetAssetImage {
                view.secondCurrencyImageView.sora.picture = .logo(image: targetAssetIcon)
                view.secondCurrencyImageView.sora.loadingPlaceholder.type = .none
            }
            
            if let rewardAssetIcon = viewModel.rewardAssetImage {
                view.rewardImageView.sora.picture = .logo(image: rewardAssetIcon)
                view.rewardImageView.sora.loadingPlaceholder.type = .none
            }
            
            view.titleLabel.sora.text = viewModel.title
            view.titleLabel.sora.loadingPlaceholder.type = .none
            
            view.subtitleLabel.sora.text = viewModel.subtitle
            view.subtitleLabel.sora.loadingPlaceholder.type = .none
            
            view.roundedAprLabel.sora.isHidden = viewModel.isFarmed
            view.secondaryInfoStackView.isHidden = !viewModel.isFarmed
            
            let isNeedShimmers = viewModel.aprText?.isEmpty ?? true
            
            view.roundedAprLabel.sora.text = viewModel.aprText
            view.roundedAprLabel.sora.loadingPlaceholder.type = isNeedShimmers ? .shimmer : .none
            
            view.thinAprLabel.sora.text = viewModel.aprText
            view.thinAprLabel.sora.loadingPlaceholder.type = isNeedShimmers ? .shimmer : .none
            
            if let percentageText = viewModel.percentageText {
                view.poolPercentageLabel.sora.text = percentageText
                view.poolPercentageLabel.sora.loadingPlaceholder.type = .none
            }
            
            view.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.farmListItem?.tapHandler?(viewModel.identifier)
            }
            
            return view
        }
        
        stackView.addArrangedSubviews(farmViews)
    }
}

extension FarmListCell: CellProtocol {
    func set(item: ItemProtocol) {
        guard let item = item as? FarmListItem else {
            assertionFailure("Incorect type of item")
            return
        }
        farmListItem = item
        titleLabel.sora.text = item.title
        updateContent(with: item.farmViewModels)
    }
}
