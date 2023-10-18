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
import SoraFoundation

final class AccountCell: SoramitsuTableViewCell {
    
    private var accountItem: AccountTableViewItem?
    private let localizationManager = LocalizationManager.shared
    
    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        return view
    }()
    
    private let accountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sora.font = FontType.displayS
        label.sora.textColor = .fgPrimary
        label.sora.lineBreakMode = .byTruncatingMiddle
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private let arrowImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.image = R.image.wallet.rightArrow()?.imageFlippedForRightToLeftLayoutDirection()
        view.sora.tintColor = .fgPrimary
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        return view
    }()
    
    private lazy var button: SoramitsuControl = {
        let view = SoramitsuControl()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let item = self?.accountItem else { return }
            self?.accountItem?.accountHandler?(item)
        }
        return view
    }()
    
    private lazy var scanQrButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 40, height: 40))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.tintColor = .accentTertiary
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        view.sora.image = R.image.wallet.qrScan()
        view.sora.cornerRadius = .circle
        view.sora.clipsToBounds = false
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.accountItem?.scanQRHandler?()
        }
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        clipsToBounds = false
        contentView.clipsToBounds = false
        contentView.addSubview(containerView)
        containerView.addSubviews([accountLabel, arrowImageView, scanQrButton])
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            accountLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            accountLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            arrowImageView.leadingAnchor.constraint(equalTo: accountLabel.trailingAnchor, constant: 12),
            arrowImageView.centerYAnchor.constraint(equalTo: accountLabel.centerYAnchor),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16),
            arrowImageView.widthAnchor.constraint(equalToConstant: 16),
            arrowImageView.trailingAnchor.constraint(lessThanOrEqualTo: scanQrButton.leadingAnchor, constant: -12),

            scanQrButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scanQrButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            scanQrButton.topAnchor.constraint(equalTo: containerView.topAnchor),
        ])
    }
}

extension AccountCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AccountTableViewItem else {
            assertionFailure("Incorect type of item")
            return
        }

        accountItem = item
        accountLabel.sora.text = item.accountName
    }
}

