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

import Foundation
import SoraUIKit
import Anchorage

final class AccountMenuItemView: SoramitsuView {
    private let titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.textM
            $0.sora.textColor = .fgPrimary
            $0.sora.backgroundColor = .custom(uiColor: .clear)
            $0.numberOfLines = 1
            $0.lineBreakMode = .byTruncatingTail
        }
    }()

    private let checkmarkView: UIImageView = {
        UIImageView().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private let iconView: UIImageView = {
        UIImageView().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private lazy var moreButton: ImageButton = {
        ImageButton(size: CGSize(width: 44, height: 44)).then {
            $0.sora.image = R.image.iconMenuInfo()
            $0.sora.tintColor = .accentTertiary
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.onMoreTap()
            }
            $0.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }
    }()

    private var model: AccountMenuItem?

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkmarkView)
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(moreButton)

        checkmarkView.do {
            $0.centerYAnchor == centerYAnchor
            $0.leadingAnchor == leadingAnchor
            $0.widthAnchor == 24
            $0.heightAnchor == 24
        }

        iconView.do {
            $0.centerYAnchor == centerYAnchor
            $0.leadingAnchor == checkmarkView.trailingAnchor + 21
            $0.sizeAnchors == CGSize(width: 40, height: 40)
            $0.topAnchor == topAnchor + 16
            $0.bottomAnchor == bottomAnchor - 16
        }

        titleLabel.do {
            $0.leadingAnchor == iconView.trailingAnchor + 8
            $0.trailingAnchor == moreButton.leadingAnchor - 8
            $0.centerYAnchor == centerYAnchor
        }

        moreButton.do {
            $0.centerYAnchor == centerYAnchor
            $0.trailingAnchor == trailingAnchor - 4
            $0.sizeAnchors == CGSize(width: 44, height: 44)
        }
        
        sora.backgroundColor = .custom(uiColor: .clear)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(model: AccountMenuItem) {
        titleLabel.sora.text = model.title
        checkmarkView.image = model.isSelected ?
        (model.isMultiselectionMode ? R.image.checkboxSelected() : R.image.checkSmall()?.tinted(with: UIColor(hex: "#EE2233"))) : (model.isMultiselectionMode ? R.image.checkboxDefault() : nil)

        moreButton.isHidden = model.isMultiselectionMode
        
        if let image = model.image {
            iconView.image = image
            iconView.isHidden = false
            iconView.widthAnchor == 40
        } else {
            iconView.isHidden = true
            iconView.widthAnchor == 0
        }
        self.model = model
    }


    @objc
    func onMoreTap() {
        if let model = self.model,
           let more = model.onMore {
            more()
        }
    }
}
