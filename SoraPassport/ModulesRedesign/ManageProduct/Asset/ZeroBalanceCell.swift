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

