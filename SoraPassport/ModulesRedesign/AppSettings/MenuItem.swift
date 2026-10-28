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
import Anchorage

class MenuItem: SoramitsuView {

    let horizontalStack: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .horizontal
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.sora.alignment = .center
        view.layoutMargins = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        view.spacing = 8
        return view
    }()

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.lineBreakMode = .byWordWrapping
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.sora.font = FontType.textM
        label.sora.dynamicTextStyle = .body
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.sora.textColor = .fgPrimary
        return label
    }()

    let leftImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let arrow: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.image = R.image.iconSmallArrow()!.imageFlippedForRightToLeftLayoutDirection().tinted(with: SoramitsuUI.shared.theme.palette.color(.accentTertiary))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let switcher: UISwitch = {
        let switcher = UISwitch(frame: .zero)
        // SORA Neon toggle: the on-track is cyan (spec §7.8).
        switcher.onTintColor = NeonTokens.current.cyan
        return switcher
    }()

    var onTap: (()->())?
    var onSwitch: ((Bool)->())?

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
        setupGestureRecognizer()
        SoramitsuUI.updates.addObserver(self)
    }

    private func setupSubviews() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(horizontalStack)

        horizontalStack.addArrangedSubviews(leftImageView)
        horizontalStack.addArrangedSubviews(titleLabel)
    }

    private func setupConstrains() {
        leftImageView.widthAnchor == 24
        arrow.widthAnchor == 24
        switcher.widthAnchor == 51
        horizontalStack.edgeAnchors == edgeAnchors
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if titleLabel.bounds.width > 0, titleLabel.preferredMaxLayoutWidth != titleLabel.bounds.width {
            titleLabel.preferredMaxLayoutWidth = titleLabel.bounds.width
            titleLabel.invalidateIntrinsicContentSize()
        }
    }

    func addArrow() {
        horizontalStack.insertArrangedSubview(arrow, at: 2)
    }

    func addSwitcher() {
        horizontalStack.insertArrangedSubview(switcher, at: 2)
        switcher.addTarget(self, action: #selector(didSwitch), for: .valueChanged)
    }

    func setupGestureRecognizer() {
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tapGR)
    }

    @objc func didTap() {
        onTap?()
    }

    @objc func didSwitch() {
        onSwitch?(switcher.isOn)
    }
}

extension MenuItem: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        guard options.contains(.palette) else { return }
        switcher.onTintColor = NeonTokens.current.cyan
        arrow.image = R.image.iconSmallArrow()?.imageFlippedForRightToLeftLayoutDirection()
            .tinted(with: SoramitsuUI.shared.theme.palette.color(.accentTertiary))
    }
}
