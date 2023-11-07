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
