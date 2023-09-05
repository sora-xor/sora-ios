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

final class MarketView: SoramitsuControl {

    let checkmarkImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.image = R.image.wallet.checkmark()
        return view
    }()
    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    let infoButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 32, height: 32))
        view.sora.tintColor = .fgSecondary
        view.sora.image = R.image.wallet.info24()
        return view
    }()
    
    public var isSelectedMarket: Bool = false {
        didSet {
            checkmarkImageView.sora.isHidden = !isSelectedMarket
        }
    }
    
    public let type: LiquiditySourceType
    
    init(type: LiquiditySourceType) {
        self.type = type
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.sora.text = type.titleForLocale(.current)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        sora.backgroundColor = .custom(uiColor: .clear)
        addSubviews(checkmarkImageView, titleLabel, infoButton)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            checkmarkImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            checkmarkImageView.centerYAnchor.constraint(equalTo: infoButton.centerYAnchor),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: checkmarkImageView.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: infoButton.centerYAnchor),
            
            infoButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            infoButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            infoButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            infoButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            infoButton.heightAnchor.constraint(equalToConstant: 32),
            infoButton.widthAnchor.constraint(equalToConstant: 32),
        ])
    }
}
