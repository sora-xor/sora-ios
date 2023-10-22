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

class MenuItem: SoramitsuView {

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
        switcher.onTintColor = SoramitsuUI.shared.theme.palette.color(.accentPrimary)
        return switcher
    }()

    var onTap: (()->())?
    var onSwitch: ((Bool)->())?

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
        switcher.widthAnchor == 51
        horizontalStack.edgeAnchors == edgeAnchors
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
