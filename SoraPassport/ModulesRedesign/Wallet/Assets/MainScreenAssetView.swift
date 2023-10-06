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
import Combine
import SoraFoundation

public final class MainScreenAssetView: SoramitsuControl {
    
    // MARK: - UI
    
    public let assetImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()
    
    public let titleLabel: SoramitsuLabel = {
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
    
    public let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.isUserInteractionEnabled = false
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
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
    
//    public let amountDownView: SoramitsuView = {
//        let view = SoramitsuView()
//        view.sora.backgroundColor = .custom(uiColor: .clear)
//        return view
//    }()
    
    public let amountDownLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .statusSuccess
        label.sora.alignment = .right
        label.sora.text = " "
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

private extension MainScreenAssetView {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(assetImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(amountUpLabel)
        addSubview(amountDownLabel)
        
//        amountDownView.addSubview(amountDownLabel)

        NSLayoutConstraint.activate([
            assetImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            assetImageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            assetImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            assetImageView.heightAnchor.constraint(equalToConstant: 40),
            assetImageView.widthAnchor.constraint(equalToConstant: 40),
            
            titleLabel.leadingAnchor.constraint(equalTo: assetImageView.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: assetImageView.topAnchor),
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            titleLabel.heightAnchor.constraint(equalToConstant: 20),
            
            amountUpLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            amountUpLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            amountUpLabel.topAnchor.constraint(equalTo: assetImageView.topAnchor),
            amountUpLabel.heightAnchor.constraint(equalToConstant: 20),
            amountUpLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            subtitleLabel.topAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: assetImageView.trailingAnchor, constant: 8),
            subtitleLabel.bottomAnchor.constraint(equalTo: assetImageView.bottomAnchor),
            subtitleLabel.heightAnchor.constraint(equalToConstant: 14),
            subtitleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            amountDownLabel.topAnchor.constraint(greaterThanOrEqualTo: amountUpLabel.bottomAnchor, constant: 1),
            amountDownLabel.leadingAnchor.constraint(equalTo: subtitleLabel.trailingAnchor, constant: 8),
            amountDownLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            amountDownLabel.bottomAnchor.constraint(equalTo: assetImageView.bottomAnchor),
            amountDownLabel.heightAnchor.constraint(equalToConstant: 14),
            amountDownLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
        ])
    }
    
    func setupSemantics() {
        let defaultAlignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        let reversedAlignment: NSTextAlignment = localizationManager.isRightToLeft ? .left : .right
        titleLabel.sora.alignment = defaultAlignment
        subtitleLabel.sora.alignment = defaultAlignment
        amountUpLabel.sora.alignment = reversedAlignment
        amountDownLabel.sora.alignment = reversedAlignment
    }
}
