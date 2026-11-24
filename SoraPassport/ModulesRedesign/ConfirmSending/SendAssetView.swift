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

import SoraUIKit
import UIKit

struct SendAssetViewModel {
    let symbol: String
    let amount: String?
    let balance: String?
    let fiat: String?
    let svgString: String?
}

final class SendAssetView: SoramitsuView {
    let assetImageView = SoramitsuImageView()
    let symbolLabel = SoramitsuLabel()
    let amountLabel = SoramitsuLabel()
    let balanceLabel = SoramitsuLabel()
    let fiatLabel = SoramitsuLabel()
    private let balanceTitle = SoramitsuLabel()
    private let balanceRow = UIStackView()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        sora.cornerRadius = .max
        sora.backgroundColor = .bgSurface
        sora.shadow = .small
        symbolLabel.sora.font = FontType.textBoldM
        symbolLabel.sora.textColor = .fgPrimary
        symbolLabel.sora.dynamicTextStyle = .headline
        amountLabel.sora.font = FontType.displayS
        amountLabel.sora.textColor = .fgPrimary
        amountLabel.sora.dynamicTextStyle = .title2
        for label in [amountLabel, symbolLabel, balanceLabel, fiatLabel] {
            label.sora.numberOfLines = 0
            label.sora.lineBreakMode = .byCharWrapping
        }
        for label in [fiatLabel, balanceLabel, balanceTitle] {
            label.sora.font = FontType.textS
            label.sora.textColor = .fgSecondary
            label.sora.dynamicTextStyle = .footnote
        }
        balanceTitle.sora.text = R.string.localizable.commonBalance(preferredLanguages: .currentLocale)
        balanceTitle.sora.numberOfLines = 0
        balanceLabel.sora.alignment = .right
        assetImageView.contentMode = .scaleAspectFit

        let identity = UIStackView(arrangedSubviews: [assetImageView, symbolLabel])
        identity.alignment = .center
        identity.spacing = 8
        balanceRow.addArrangedSubview(balanceTitle)
        balanceRow.addArrangedSubview(balanceLabel)
        balanceRow.alignment = .firstBaseline
        balanceRow.spacing = 12
        balanceTitle.setContentHuggingPriority(.required, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: [identity, amountLabel, fiatLabel, balanceRow])
        stack.axis = .vertical
        stack.spacing = 4
        stack.setCustomSpacing(10, after: identity)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        let bottom = stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        bottom.priority = UILayoutPriority(999)
        let iconWidth = assetImageView.widthAnchor.constraint(equalToConstant: 28)
        iconWidth.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            iconWidth, assetImageView.heightAnchor.constraint(equalTo: assetImageView.widthAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18), bottom,
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }

    func setImage(_ image: UIImage?) {
        assetImageView.image = image
        assetImageView.isHidden = image == nil
    }

    func setValues(symbol: String, amount: String?, balance: String?, fiat: String?) {
        symbolLabel.sora.text = symbol
        amountLabel.sora.text = amount
        balanceLabel.sora.text = balance
        balanceRow.isHidden = balance?.isEmpty ?? true
        balanceTitle.isHidden = balance == WalletUX.balanceUnavailableText
        fiatLabel.sora.text = fiat
        fiatLabel.isHidden = fiat?.isEmpty ?? true
    }

    func setupView(with model: SendAssetViewModel?) {
        guard let model else { return }
        setImage(model.svgString.flatMap { RemoteSerializer.shared.image(with: $0) })
        setValues(symbol: model.symbol, amount: model.amount, balance: model.balance, fiat: model.fiat)
    }
}
