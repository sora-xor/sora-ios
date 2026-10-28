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

class AccountOptionItem: SoramitsuView {

    let horizontalStack: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .horizontal
        view.sora.cornerRadius = .max
        view.sora.distribution = .fillProportionally
        view.layoutMargins = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        view.spacing = 8
        return view
    }()

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        return label
    }()

    let leftImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.sora.tintColor = .fgSecondary
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let arrow: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.image = R.image.iconSmallArrow()!
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    var onTap: (()->())?

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
        setupGestureRecognizer()
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
        titleLabel.heightAnchor == 24
        horizontalStack.edgeAnchors == edgeAnchors
    }

    func addArrow() {
        horizontalStack.insertArrangedSubview(arrow, at: 2)
    }

    func setupGestureRecognizer() {
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tapGR)
    }

    @objc func didTap() {
        onTap?()
    }
}
