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

@IBDesignable
final class RoundedCellControlView: BackgroundedContentControl {

    private(set) var roundedBackgroundView: RoundedView!
    private(set) var borderView: BorderedContainerView!
    private(set) var titleAccessoryView: TitleWithAccessoryView!

    var highlitedOnAnimation: ViewAnimatorProtocol?
    var highlitedOffAnimation: ViewAnimatorProtocol?

    override var isHighlighted: Bool {
        get {
            return super.isHighlighted
        }

        set {
            let oldValue = super.isHighlighted
            super.isHighlighted = newValue

            if let animation = highlitedOnAnimation, !oldValue, newValue {
                layer.removeAllAnimations()
                animation.animate(view: self, completionBlock: nil)
            }

            if let animation = highlitedOffAnimation, oldValue, !newValue {
                layer.removeAllAnimations()
                animation.animate(view: self, completionBlock: nil)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
       super.init(coder: coder)

        configure()
    }

    override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        if let contentView = contentView {
            var frame = contentView.frame
            frame = CGRect(x: contentInsets.left,
                           y: frame.origin.y,
                           width: bounds.size.width - contentInsets.left - contentInsets.right,
                           height: frame.size.height)
            contentView.frame = frame
        }

        borderView.frame = roundedBackgroundView.bounds
    }

    private func configure() {
        backgroundColor = .clear

        if backgroundView == nil {
            roundedBackgroundView = RoundedView()
            roundedBackgroundView.isUserInteractionEnabled = false

            borderView = BorderedContainerView()
            borderView.borderType = [.bottom]
            roundedBackgroundView.addSubview(borderView)

            self.backgroundView = roundedBackgroundView
        }

        if contentView == nil {
            titleAccessoryView = TitleWithAccessoryView()
            titleAccessoryView.isUserInteractionEnabled = false
            self.contentView = titleAccessoryView
        }
    }
}
