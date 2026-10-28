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

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            
            errorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            errorView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            errorView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
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
    }
}

