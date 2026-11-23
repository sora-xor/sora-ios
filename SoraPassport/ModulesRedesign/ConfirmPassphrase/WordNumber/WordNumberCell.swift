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

final class WordNumberCell: SoramitsuTableViewCell {
    
    private var wordNumberItem: WordNumberItem?

    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        return view
    }()
    
    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.mnemonicConfirmationSelectWordNumber(preferredLanguages: .currentLocale)
        label.sora.font = FontType.paragraphM
        label.sora.dynamicTextStyle = .body
        label.numberOfLines = 0
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .center
        return label
    }()

    private let numberLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.text = ""
        label.font = UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: .monospacedDigitSystemFont(ofSize: 56, weight: .semibold), maximumPointSize: 84)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = Lit.lacquerText
        label.textAlignment = .center
        return label
    }()
    
    private let progress: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.progressTintColor = Lit.lacquerRed
        view.trackTintColor = Lit.wellFloor
        view.accessibilityLabel = R.string.localizable.accountConfirmationTitleV2(preferredLanguages: .currentLocale)
        return view
    }()

    private let buttonsStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .vertical
        view.sora.distribution = .fillEqually
        view.spacing = 16
        view.sora.clipsToBounds = false
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
        contentView.addSubviews(containerView)
        contentView.addSubviews(buttonsStackView)
        containerView.addSubviews(titleLabel, numberLabel, progress)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            
            numberLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            numberLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            numberLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),

            progress.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            progress.widthAnchor.constraint(equalToConstant: 88),
            progress.topAnchor.constraint(equalTo: numberLabel.bottomAnchor, constant: 12),
            progress.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),

            buttonsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            buttonsStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 24),
            buttonsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}

extension WordNumberCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? WordNumberItem else {
            assertionFailure("Incorect type of item")
            return
        }
        wordNumberItem = item
        
        progress.setProgress(Float(item.currentStage) / 3, animated: window != nil && LitMotion.allowed)
        buttonsStackView.removeArrangedSubviews()
        for variant in item.variants {
            let button = WalletSafeMode.button(.secondary, title: variant)
            button.addAction(UIAction { [weak self] _ in
                self?.wordNumberItem?.tryHandler?(variant)
            }, for: .touchUpInside)
            buttonsStackView.addArrangedSubview(button)
        }

        let position = "\(item.index)"
        if numberLabel.text != position, window != nil { LitMotion.rise(numberLabel, by: 5) }
        numberLabel.text = position
        accessibilityElements = [titleLabel, numberLabel, progress] + buttonsStackView.arrangedSubviews

    }
}

