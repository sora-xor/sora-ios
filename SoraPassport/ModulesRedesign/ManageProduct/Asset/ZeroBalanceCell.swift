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

final class ZeroBalanceCell: SoramitsuTableViewCell {

    private var item: ZeroBalanceItem?

    private lazy var button: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.tintColor = .accentSecondary
        button.sora.backgroundColor = .bgSurfaceVariant
        button.sora.rightImage = R.image.wallet.arrow()
        button.sora.horizontalOffset = 12
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.item?.buttonHandler?()
        }
        button.sora.cornerRadius = .small
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(button)

    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            button.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            button.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            button.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
}

extension ZeroBalanceCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ZeroBalanceItem else {
            assertionFailure("Incorect type of item")
            return
        }

        let text = item.isShown ?
        R.string.localizable.hideZeroBalances(preferredLanguages: .currentLocale) :
        R.string.localizable.showZeroBalances(preferredLanguages: .currentLocale)


        let textItem = SoramitsuTextItem(text: text,
                                         fontData: FontType.textBoldS,
                                         textColor: .accentSecondary,
                                         alignment: .center)
        button.sora.attributedText = textItem

        UIView.animate(withDuration: 0.3) {
            self.button.rightImageView.transform = item.isShown ? CGAffineTransform(rotationAngle: .pi) : CGAffineTransform.identity
        }

        self.item = item
    }
}

