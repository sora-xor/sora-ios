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
import Anchorage

class CategoryItem: SoramitsuView {

    let horizontalStack: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .horizontal
        view.sora.cornerRadius = .max
        view.sora.distribution = .fillProportionally
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
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

    let subtitleView: SoramitsuView = {
        var view = SoramitsuView(frame: .zero)
        view.sora.backgroundColor = .bgSurface
        return view
    }()

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
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
        return view
    }()

    let rightImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstraints()
    }

    private func setupSubviews() {

        translatesAutoresizingMaskIntoConstraints = false

        addSubview(horizontalStack)

        subtitleView.addSubview(subtitleLabel)

        verticalStack.addArrangedSubviews(titleLabel)
        verticalStack.addArrangedSubviews(subtitleView)

        horizontalStack.addArrangedSubviews(verticalStack)
        horizontalStack.addArrangedSubviews(rightImageView)
    }

    private func setupConstraints() {
        rightImageView.widthAnchor == 24
        subtitleView.heightAnchor == 14
        horizontalStack.edgeAnchors == edgeAnchors
        subtitleLabel.leadingAnchor == subtitleView.leadingAnchor
        subtitleLabel.trailingAnchor == subtitleView.trailingAnchor
    }

    func addCircle() {
        subtitleView.addSubview(circle)
        circle.heightAnchor == 8
        circle.widthAnchor == 8
        circle.topAnchor == subtitleView.topAnchor + 3
        circle.leadingAnchor == subtitleView.leadingAnchor
        subtitleLabel.leadingAnchor == circle.trailingAnchor + 4
    }
}
