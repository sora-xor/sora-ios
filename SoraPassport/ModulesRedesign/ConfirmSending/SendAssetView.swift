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
import SSFUtils

struct SendAssetViewModel {
    let symbol: String
    let amount: String?
    let balance: String?
    let fiat: String?
    let svgString: String?
}

final class SendAssetView: SoramitsuView {
    
    private let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.shadow = .small
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        return view
    }()
    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.headline4
        label.sora.text = R.string.localizable.sendAsset(preferredLanguages: .currentLocale).uppercased()
        return label
    }()
    
    let assetImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        return imageView
    }()
    
    let symbolLabel: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.displayS
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    let amountLabel: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.displayS
        return label
    }()
    
    let balanceLabel: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        return label
    }()
    
    let fiatLabel: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.sora.alignment = .right
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupView()
        setupConstraints()
    }
    
    private func setupView() {
        sora.clipsToBounds = false
        sora.backgroundColor = .custom(uiColor: .clear)
        addSubviews(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(assetImageView)
        containerView.addSubview(symbolLabel)
        containerView.addSubview(amountLabel)
        containerView.addSubview(balanceLabel)
        containerView.addSubview(fiatLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            
            assetImageView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            assetImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            assetImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32),
            assetImageView.widthAnchor.constraint(equalToConstant: 40),
            assetImageView.heightAnchor.constraint(equalToConstant: 40),
            
            symbolLabel.leadingAnchor.constraint(equalTo: assetImageView.trailingAnchor, constant: 8),
            symbolLabel.topAnchor.constraint(equalTo: assetImageView.topAnchor),
            
            balanceLabel.leadingAnchor.constraint(equalTo: assetImageView.trailingAnchor, constant: 8),
            balanceLabel.bottomAnchor.constraint(equalTo: assetImageView.bottomAnchor),
            
            amountLabel.leadingAnchor.constraint(equalTo: symbolLabel.trailingAnchor, constant: 8),
            amountLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            amountLabel.topAnchor.constraint(equalTo: assetImageView.topAnchor),
            
            fiatLabel.leadingAnchor.constraint(equalTo: balanceLabel.trailingAnchor, constant: 8),
            fiatLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            fiatLabel.bottomAnchor.constraint(equalTo: assetImageView.bottomAnchor),
            
        ])
    }
}

extension SendAssetView {
    func setupView(with viewModel: SendAssetViewModel?) {
        guard let viewModel = viewModel else { return }
        assetImageView.image = RemoteSerializer.shared.image(with: viewModel.svgString ?? "")
        symbolLabel.sora.text = viewModel.symbol
        balanceLabel.sora.text = viewModel.balance
        amountLabel.sora.text = viewModel.amount
        fiatLabel.sora.text = viewModel.fiat
    }
}
