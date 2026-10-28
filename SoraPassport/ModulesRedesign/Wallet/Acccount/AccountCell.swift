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
        containerView.addSubviews(accountLabel, arrowImageView, scanQrButton)
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

