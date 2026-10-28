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

public final class ActivityView: SoramitsuControl {

    public var isRightToLeft: Bool = false {
        didSet {
            setupSemantics()
        }
    }

    // MARK: - UI

    var firstCurrencyHeightContstaint: NSLayoutConstraint?
    
    public let currenciesView: SoramitsuView = {
        let view = SoramitsuView()
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        view.widthAnchor.constraint(equalToConstant: 40).isActive = true
        return view
    }()

    public let firstCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()

    public let secondCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 28).isActive = true
        view.widthAnchor.constraint(equalToConstant: 28).isActive = true
        view.isHidden = true
        return view
    }()
    
    public let oneCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 32).isActive = true
        view.widthAnchor.constraint(equalToConstant: 32).isActive = true
        return view
    }()
    
    public let transactionTypeView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        view.sora.cornerRadius = .custom(8)
        view.sora.tintColor = .fgSecondary
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        return view
    }()
    
    public let transactionTypeImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        view.sora.tintColor = .fgSecondary
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 12).isActive = true
        view.widthAnchor.constraint(equalToConstant: 12).isActive = true
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()

    public let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    public let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return label
    }()

    public let amountUpLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .right
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    public let statusImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.sora.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        return view
    }()
    
    public let amountView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.axis = .horizontal
        view.sora.distribution = .fill
        view.spacing = 4
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.cornerRadius = .circle
        return view
    }()

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension ActivityView {
    func setup() {
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false
        
        amountView.addArrangedSubviews([amountUpLabel, statusImageView])
        addSubviews(currenciesView, titleLabel, subtitleLabel, amountView)
        
        transactionTypeView.addSubview(transactionTypeImageView)

        currenciesView.addSubview(firstCurrencyImageView)
        currenciesView.addSubview(secondCurrencyImageView)
        currenciesView.addSubview(oneCurrencyImageView)
        currenciesView.addSubview(transactionTypeView)

        firstCurrencyHeightContstaint = firstCurrencyImageView.heightAnchor.constraint(equalToConstant: 28)
        firstCurrencyHeightContstaint?.isActive = true
        
        NSLayoutConstraint.activate([
            firstCurrencyImageView.leadingAnchor.constraint(equalTo: currenciesView.leadingAnchor),
            firstCurrencyImageView.topAnchor.constraint(equalTo: currenciesView.topAnchor),

            secondCurrencyImageView.trailingAnchor.constraint(equalTo: currenciesView.trailingAnchor),
            secondCurrencyImageView.bottomAnchor.constraint(equalTo: currenciesView.bottomAnchor),
            
            oneCurrencyImageView.centerXAnchor.constraint(equalTo: currenciesView.centerXAnchor),
            oneCurrencyImageView.centerYAnchor.constraint(equalTo: currenciesView.centerYAnchor),
            
            transactionTypeView.leadingAnchor.constraint(equalTo: currenciesView.leadingAnchor),
            transactionTypeView.bottomAnchor.constraint(equalTo: currenciesView.bottomAnchor),
            
            transactionTypeImageView.centerXAnchor.constraint(equalTo: transactionTypeView.centerXAnchor),
            transactionTypeImageView.centerYAnchor.constraint(equalTo: transactionTypeView.centerYAnchor),
            
            currenciesView.leadingAnchor.constraint(equalTo: leadingAnchor),
            currenciesView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            currenciesView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: currenciesView.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: currenciesView.topAnchor, constant: 2),
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 10),
            titleLabel.heightAnchor.constraint(equalToConstant: 16),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: currenciesView.trailingAnchor, constant: 8),
            subtitleLabel.bottomAnchor.constraint(equalTo: currenciesView.bottomAnchor, constant: -2),
            subtitleLabel.heightAnchor.constraint(equalToConstant: 12),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            amountView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            amountView.trailingAnchor.constraint(equalTo: trailingAnchor),
            amountView.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            amountView.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            amountView.bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            amountView.heightAnchor.constraint(equalToConstant: 16),
            
            statusImageView.trailingAnchor.constraint(equalTo: amountView.trailingAnchor),
            
            amountUpLabel.trailingAnchor.constraint(equalTo: statusImageView.leadingAnchor, constant: -4),
            amountUpLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
        ])
    }
    
    private func setupSemantics() {
        let alignment: NSTextAlignment = isRightToLeft ? .right : .left
        titleLabel.sora.alignment = alignment
        subtitleLabel.sora.alignment = alignment
    }
}
