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
import UIKit

final class PoolDetailsHeaderView: SoramitsuControl {

    public let currenciesView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.isUserInteractionEnabled = false
        return view
    }()
    
    public let firstCurrencyImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    
    public let secondCurrencyImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
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
        
        addSubviews(currenciesView, titleLabel)
        
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
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
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
