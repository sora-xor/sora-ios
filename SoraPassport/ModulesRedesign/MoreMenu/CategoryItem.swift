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

class CategoryItem: SoramitsuView {

    private let iconPad = UIView()
    private lazy var padBacking = LitBacking(host: iconPad)

    override func layoutSubviews() {
        super.layoutSubviews()
        padBacking.layout(radius: 14)
    }

    let horizontalStack: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .horizontal
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.sora.alignment = .center
        view.spacing = 14
        view.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    let verticalStack: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.spacing = 4
        view.sora.distribution = .fill
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    let subtitleView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .horizontal
        view.sora.distribution = .fill
        view.sora.alignment = .center
        view.spacing = 4
        return view
    }()

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 0
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        return label
    }()

    let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()

    let circle: SoramitsuView = {
        let view = SoramitsuView(frame: .zero)
        view.sora.cornerRadius = .circle
        view.sora.clipsToBounds = true
        view.sora.isHidden = true
        view.heightAnchor == 8
        view.widthAnchor == 8
        return view
    }()

    let rightImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor == 24
        return imageView
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstraints()
    }

    private func setupSubviews() {
        addSubview(horizontalStack)

        subtitleView.addArrangedSubviews([circle, subtitleLabel])

        verticalStack.addArrangedSubviews(titleLabel)
        verticalStack.addArrangedSubviews(subtitleView)

        iconPad.addSubview(rightImageView)
        iconPad.translatesAutoresizingMaskIntoConstraints = false
        iconPad.widthAnchor == 38
        iconPad.heightAnchor == 38
        rightImageView.heightAnchor == 24
        rightImageView.centerAnchors == iconPad.centerAnchors
        padBacking.style = .raised(elevation: 2)
        horizontalStack.addArrangedSubviews(iconPad, verticalStack)
    }

    private func setupConstraints() {
        horizontalStack.edgeAnchors == edgeAnchors
    }

    func addCircle() {
        circle.sora.isHidden = false
    }
    
    func hideCircle() {
        circle.sora.isHidden = true
    }
}
