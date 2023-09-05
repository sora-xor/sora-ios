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
import SoraUI

class TitleWithAccessoryView: UIView {
    private(set) var titleView: ImageWithTitleView!
    private(set) var accessoryLabel: UILabel!

    override var intrinsicContentSize: CGSize {
        let height = max(titleView.intrinsicContentSize.height,
                         accessoryLabel.intrinsicContentSize.height)
        let width = titleView.intrinsicContentSize.width + accessoryLabel.intrinsicContentSize.width
        return CGSize(width: width, height: height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func configure() {
        backgroundColor = .clear

        titleView = ImageWithTitleView()
        titleView.translatesAutoresizingMaskIntoConstraints = false
        titleView.layoutType = .horizontalImageFirst
        addSubview(titleView)

        accessoryLabel = UILabel()
        accessoryLabel.translatesAutoresizingMaskIntoConstraints = false
        accessoryLabel.textAlignment = .right
        addSubview(accessoryLabel)

        titleView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        titleView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        accessoryLabel.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        accessoryLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        titleView.trailingAnchor.constraint(equalTo: accessoryLabel.leadingAnchor).isActive = true

        titleView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        accessoryLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        titleView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        accessoryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}
