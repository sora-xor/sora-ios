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

final class ActivityErrorCell: SoramitsuTableViewCell {

    private var errorItem: ActivityErrorItem?
    
    private let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerMask = .top
        view.sora.cornerRadius = .extraLarge
        return view
    }()

    private lazy var errorView: ErrorView = {
        let title = SoramitsuTextItem(text: R.string.localizable.commonRefresh(preferredLanguages: .currentLocale),
                                      fontData: FontType.textBoldS,
                                      textColor: .fgSecondary,
                                      alignment: .center)
        
        let view = ErrorView()
        view.titleLabel.sora.text = R.string.localizable.activityDataNotUpToDateTitle(preferredLanguages: .currentLocale)
        view.button.sora.attributedText = title
        view.button.sora.associate(states: .pressed) { [weak self] _ in
            self?.errorItem?.handler?()
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
        contentView.addSubview(containerView)
        contentView.addSubview(errorView)
    }

    private lazy var errorViewTop = errorView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8)

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            
            // 24 at the sides, as the rows of the list have: a text of
            // more than one line must not run into the rounded corners.
            errorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            errorView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            errorViewTop,
            errorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])
    }
}

extension ActivityErrorCell: CellProtocol {
    func set(item: ItemProtocol) {
        guard let item = item as? ActivityErrorItem else {
            assertionFailure("Incorect type of item")
            return
        }

        errorItem = item
        // The cell is reused: set the text for every item. A row with its
        // own text is the first of the list, under the rounded corners.
        errorView.titleLabel.sora.text = item.title
            ?? R.string.localizable.activityDataNotUpToDateTitle(preferredLanguages: .currentLocale)
        errorViewTop.constant = item.title == nil ? 8 : 20
        containerView.sora.cornerMask = item.roundsTop ? .top : .none
    }
}


/// Shows an `ActivityNoticeItem`: informational text only, no action.
final class ActivityNoticeCell: SoramitsuTableViewCell {

    private let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerMask = .top
        view.sora.cornerRadius = .extraLarge
        return view
    }()

    private let noticeLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgSecondary
        label.sora.alignment = .center
        label.sora.numberOfLines = 0
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(containerView)
        contentView.addSubview(noticeLabel)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            noticeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            noticeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            noticeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            noticeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

extension ActivityNoticeCell: CellProtocol {
    func set(item: ItemProtocol) {
        guard let item = item as? ActivityNoticeItem else {
            assertionFailure("Incorect type of item")
            return
        }

        noticeLabel.sora.text = item.text
        accessibilityLabel = item.text
        containerView.sora.cornerMask = item.roundsTop ? .top : .none
    }
}
