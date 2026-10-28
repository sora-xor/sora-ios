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
import UIKit

final class PoolDetailsHeaderView: SoramitsuControl {

    public let currenciesView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.isUserInteractionEnabled = false
        return view
    }()
    
    public let firstCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.isUserInteractionEnabled = false
        return view
    }()
    
    public let secondCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.isUserInteractionEnabled = false
        return view
    }()
    
    public let rewardViewContainter: SoramitsuView = {
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
        return view
    }()
    
    public let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    public let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    public let typeImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    init() {
        super.init(frame: .zero)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        sora.backgroundColor = .custom(uiColor: .clear)
        
        addSubviews(currenciesView, titleLabel, subtitleLabel, typeImageView)
        
        currenciesView.addSubview(firstCurrencyImageView)
        rewardViewContainter.addSubviews(rewardImageView)
        
        currenciesView.addSubview(secondCurrencyImageView)
        currenciesView.addSubview(rewardViewContainter)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            currenciesView.leadingAnchor.constraint(equalTo: leadingAnchor),
            currenciesView.topAnchor.constraint(equalTo: topAnchor),
            currenciesView.centerYAnchor.constraint(equalTo: centerYAnchor),
            currenciesView.heightAnchor.constraint(equalToConstant: 40),
            currenciesView.widthAnchor.constraint(equalToConstant: 64),
            
            titleLabel.leadingAnchor.constraint(equalTo: currenciesView.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: typeImageView.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: currenciesView.topAnchor),
            
            subtitleLabel.heightAnchor.constraint(equalToConstant: 15),
            subtitleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            subtitleLabel.leadingAnchor.constraint(equalTo: currenciesView.trailingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: typeImageView.leadingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(equalTo: currenciesView.bottomAnchor),
            
            typeImageView.heightAnchor.constraint(equalToConstant: 24),
            typeImageView.widthAnchor.constraint(equalToConstant: 24),
            typeImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            typeImageView.topAnchor.constraint(equalTo: topAnchor),
            
            firstCurrencyImageView.leadingAnchor.constraint(equalTo: currenciesView.leadingAnchor),
            firstCurrencyImageView.centerYAnchor.constraint(equalTo: currenciesView.centerYAnchor),
            firstCurrencyImageView.topAnchor.constraint(equalTo: currenciesView.topAnchor),
            firstCurrencyImageView.heightAnchor.constraint(equalToConstant: 40),
            firstCurrencyImageView.widthAnchor.constraint(equalToConstant: 40),
            
            secondCurrencyImageView.leadingAnchor.constraint(equalTo: firstCurrencyImageView.leadingAnchor, constant: 24),
            secondCurrencyImageView.heightAnchor.constraint(equalToConstant: 40),
            secondCurrencyImageView.widthAnchor.constraint(equalToConstant: 40),
            
            rewardImageView.trailingAnchor.constraint(equalTo: secondCurrencyImageView.trailingAnchor),
            rewardImageView.bottomAnchor.constraint(equalTo: secondCurrencyImageView.bottomAnchor),
            rewardImageView.heightAnchor.constraint(equalToConstant: 18),
            rewardImageView.widthAnchor.constraint(equalToConstant: 18),

            rewardViewContainter.centerXAnchor.constraint(equalTo: rewardImageView.centerXAnchor),
            rewardViewContainter.centerYAnchor.constraint(equalTo: rewardImageView.centerYAnchor),
            rewardViewContainter.heightAnchor.constraint(equalToConstant: 22),
            rewardViewContainter.widthAnchor.constraint(equalToConstant: 22)
        ])
    }
}
