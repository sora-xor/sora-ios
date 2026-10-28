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

public final class ExplorePoolView: SoramitsuView {
    
    // MARK: - UI
    
    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.isUserInteractionEnabled = false
        return stackView
    }()
    
    public lazy var serialNumber: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.alignment = localizationManager.isRightToLeft ? .right : .left
        label.widthAnchor.constraint(equalToConstant: 30).isActive = true
        return label
    }()
    
    let currenciesView: SoramitsuView = {
        let view = SoramitsuView()
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        view.widthAnchor.constraint(equalToConstant: 64).isActive = true
        view.sora.isUserInteractionEnabled = false
        return view
    }()
    
    let firstCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        view.widthAnchor.constraint(equalToConstant: 40).isActive = true
        view.isUserInteractionEnabled = false
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()
    
    let secondCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        view.widthAnchor.constraint(equalToConstant: 40).isActive = true
        view.isUserInteractionEnabled = false
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()
    
    let infoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.isUserInteractionEnabled = false
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
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
    
    let amountUpLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .center
        label.sora.backgroundColor = .bgSurfaceVariant
        label.sora.cornerRadius = .circle
        label.sora.contentInsets = SoramitsuInsets(top: 0, left: 10, bottom: 0, right: 10)
        label.sora.isUserInteractionEnabled = false
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        label.heightAnchor.constraint(equalToConstant: 32).isActive = true
        label.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
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
}

private extension ExplorePoolView {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        addSubview(amountUpLabel)
        
        currenciesView.addSubview(firstCurrencyImageView)
        currenciesView.addSubview(secondCurrencyImageView)
        
        infoStackView.addArrangedSubview(titleLabel)
        infoStackView.addArrangedSubview(subtitleLabel)
        
        stackView.addArrangedSubview(serialNumber)
        stackView.addArrangedSubview(currenciesView)
        stackView.setCustomSpacing(8, after: currenciesView)
        stackView.addArrangedSubview(infoStackView)
        stackView.setCustomSpacing(8, after: infoStackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 40),
            
            amountUpLabel.leadingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 8),
            amountUpLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            amountUpLabel.centerYAnchor.constraint(equalTo: stackView.centerYAnchor),
            
            firstCurrencyImageView.leadingAnchor.constraint(equalTo: currenciesView.leadingAnchor),
            firstCurrencyImageView.centerYAnchor.constraint(equalTo: currenciesView.centerYAnchor),
            firstCurrencyImageView.topAnchor.constraint(equalTo: currenciesView.topAnchor),

            secondCurrencyImageView.leadingAnchor.constraint(equalTo: firstCurrencyImageView.leadingAnchor, constant: 24),
            secondCurrencyImageView.trailingAnchor.constraint(equalTo: currenciesView.trailingAnchor),
            secondCurrencyImageView.centerYAnchor.constraint(equalTo: currenciesView.centerYAnchor),
        ])
    }
    
    func setupSemantics() {
        let alignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        titleLabel.sora.alignment = alignment
        subtitleLabel.sora.alignment = alignment
    }
}
