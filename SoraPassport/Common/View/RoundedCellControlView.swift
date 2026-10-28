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
