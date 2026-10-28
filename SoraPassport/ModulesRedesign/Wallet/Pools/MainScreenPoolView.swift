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

import Foundation
import SoraUIKit
import SoraFoundation

public final class MainScreenPoolView: SoramitsuControl {
    
    // MARK: - UI
    
    let currenciesView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.isUserInteractionEnabled = false
        return view
    }()
    
    let firstCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()
    
    let secondCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()

    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.isUserInteractionEnabled = false
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.sora.isUserInteractionEnabled = false
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return label
    }()
    
    let rewardViewContainter: SoramitsuView = {
        let view = SoramitsuView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgPage
        view.sora.cornerRadius = .circle
        view.sora.isUserInteractionEnabled = false
        return view
    }()
    
    public let rewardImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.cornerRadius = .circle
        view.sora.borderColor = .bgPage
        view.sora.isUserInteractionEnabled = false
        view.sora.backgroundColor = .additionalPolkaswap
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()
    
    public let amountUpLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .right
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return label
    }()
    
    public let farmedRewardAssetStackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.alignment = .trailing
        stackView.sora.axis = .horizontal
        stackView.sora.distribution = .fill
        stackView.spacing = 8
        stackView.sora.loadingPlaceholder.type = .shimmer
        stackView.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return stackView
    }()

    private let localizationManager = LocalizationManager.shared
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setup()
        setupSemantics()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setupFarmedAssetImages(pictures: [Picture]) {
        farmedRewardAssetStackView.removeArrangedSubviews()
        
        let images = pictures.map { picture in
            let image = SoramitsuImageView()
            image.heightAnchor.constraint(equalToConstant: 14).isActive = true
            image.widthAnchor.constraint(equalToConstant: 14).isActive = true
            image.sora.picture = picture
            return image
        }

        farmedRewardAssetStackView.addArrangedSubviews(images)
    }
}

private extension MainScreenPoolView {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        
        rewardViewContainter.addSubview(rewardImageView)
        
        currenciesView.addSubview(firstCurrencyImageView)
        currenciesView.addSubview(secondCurrencyImageView)
        currenciesView.addSubview(rewardViewContainter)
        
        addSubview(currenciesView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(amountUpLabel)
        addSubview(farmedRewardAssetStackView)

        NSLayoutConstraint.activate([
            firstCurrencyImageView.leadingAnchor.constraint(equalTo: currenciesView.leadingAnchor),
            firstCurrencyImageView.centerYAnchor.constraint(equalTo: currenciesView.centerYAnchor),
            firstCurrencyImageView.topAnchor.constraint(equalTo: currenciesView.topAnchor),
            firstCurrencyImageView.heightAnchor.constraint(equalToConstant: 40),
            firstCurrencyImageView.widthAnchor.constraint(equalToConstant: 40),
            
            secondCurrencyImageView.leadingAnchor.constraint(equalTo: firstCurrencyImageView.leadingAnchor, constant: 24),
            secondCurrencyImageView.centerYAnchor.constraint(equalTo: currenciesView.centerYAnchor),
            secondCurrencyImageView.trailingAnchor.constraint(equalTo: currenciesView.trailingAnchor),
            secondCurrencyImageView.heightAnchor.constraint(equalToConstant: 40),
            secondCurrencyImageView.widthAnchor.constraint(equalToConstant: 40),
            
            rewardViewContainter.centerXAnchor.constraint(equalTo: rewardImageView.centerXAnchor),
            rewardViewContainter.centerYAnchor.constraint(equalTo: rewardImageView.centerYAnchor),
            rewardViewContainter.heightAnchor.constraint(equalToConstant: 22),
            rewardViewContainter.widthAnchor.constraint(equalToConstant: 22),
            
            rewardImageView.trailingAnchor.constraint(equalTo: secondCurrencyImageView.trailingAnchor),
            rewardImageView.bottomAnchor.constraint(equalTo: secondCurrencyImageView.bottomAnchor),
            rewardImageView.heightAnchor.constraint(equalToConstant: 18),
            rewardImageView.widthAnchor.constraint(equalToConstant: 18),
            
            currenciesView.leadingAnchor.constraint(equalTo: leadingAnchor),
            currenciesView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            currenciesView.centerYAnchor.constraint(equalTo: centerYAnchor),
            currenciesView.heightAnchor.constraint(equalToConstant: 40),
            currenciesView.widthAnchor.constraint(equalToConstant: 64),
            
            titleLabel.leadingAnchor.constraint(equalTo: currenciesView.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: currenciesView.topAnchor),
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            titleLabel.heightAnchor.constraint(equalToConstant: 20),
            
            amountUpLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            amountUpLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            amountUpLabel.topAnchor.constraint(equalTo: currenciesView.topAnchor),
            amountUpLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            amountUpLabel.heightAnchor.constraint(equalToConstant: 20),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: currenciesView.trailingAnchor, constant: 8),
            subtitleLabel.trailingAnchor.constraint(equalTo: farmedRewardAssetStackView.leadingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(equalTo: currenciesView.bottomAnchor),
            subtitleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            subtitleLabel.heightAnchor.constraint(equalToConstant: 14),
            
            farmedRewardAssetStackView.topAnchor.constraint(greaterThanOrEqualTo: amountUpLabel.bottomAnchor, constant: 1),
            farmedRewardAssetStackView.leadingAnchor.constraint(equalTo: subtitleLabel.trailingAnchor, constant: 8),
            farmedRewardAssetStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            farmedRewardAssetStackView.bottomAnchor.constraint(equalTo: currenciesView.bottomAnchor),
            farmedRewardAssetStackView.heightAnchor.constraint(equalToConstant: 14),
        ])
    }
    
    func setupSemantics() {
        let alignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        let reversedAlignment: NSTextAlignment = localizationManager.isRightToLeft ? .left : .right
        titleLabel.sora.alignment = alignment
        subtitleLabel.sora.alignment = alignment
        amountUpLabel.sora.alignment = reversedAlignment
    }
}
