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
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: currenciesView.bottomAnchor),
            subtitleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            subtitleLabel.heightAnchor.constraint(equalToConstant: 14)
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
