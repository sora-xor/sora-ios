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

final class DetailView: SoramitsuControl {

    let leftInfoStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.alignment = .leading
        view.spacing = 4
        return view
    }()
    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    let infoButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 14, height: 14))
        view.sora.isHidden = true
        view.sora.tintColor = .fgSecondary
        view.sora.image = R.image.wallet.info()
        return view
    }()
    
    let rightInfoStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.alignment = .center
        view.spacing = 8
        return view
    }()
    
    let assetImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }()
    
    let valueLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.sora.backgroundColor = .custom(uiColor: .clear)
        return label
    }()
    
    let fiatValueLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.backgroundColor = .custom(uiColor: .clear)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    let progressView: ProgressView = {
        let view = ProgressView()
        view.sora.isHidden = true
        view.sora.cornerRadius = .circle
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.heightAnchor.constraint(equalToConstant: 4).isActive = true
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
        
        addSubviews(leftInfoStackView, rightInfoStackView)
        
        leftInfoStackView.addArrangedSubviews(titleLabel, infoButton)
        rightInfoStackView.addArrangedSubviews(progressView, assetImageView, valueLabel, fiatValueLabel)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            leftInfoStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            leftInfoStackView.centerYAnchor.constraint(equalTo: rightInfoStackView.centerYAnchor),
            leftInfoStackView.trailingAnchor.constraint(lessThanOrEqualTo: rightInfoStackView.leadingAnchor),
            
            rightInfoStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightInfoStackView.topAnchor.constraint(equalTo: topAnchor),
            rightInfoStackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
