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

import UIKit
import SoraUI

class DetailsRoundedView: BackgroundedContentControl {
    enum Layout {
        case singleTitle
        case largeIconTitleSubtitle
        case smallIconTitleSubtitle
    }

    var triangularedBackgroundView: RoundedView? {
        backgroundView as? RoundedView
    }

    private(set) var titleLabel: UILabel!
    private(set) var subtitleLabel: UILabel?

    var iconView: UIImageView { lazyIconViewOrCreateIfNeeded() }
    var actionView: UIImageView { lazyActionViewOrCreateIfNeeded() }

    private var lazyIconView: UIImageView?
    private var lazyActionView: UIImageView?

    var horizontalSpacing: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var iconRadius: CGFloat = 16.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var layout: Layout = .largeIconTitleSubtitle {
        didSet {
            switch layout {
            case .largeIconTitleSubtitle, .smallIconTitleSubtitle:
                if subtitleLabel == nil {
                    let label = UILabel()
                    subtitleLabel = label
                    contentView?.addSubview(label)
                }
            case .singleTitle:
                if subtitleLabel != nil {
                    subtitleLabel?.removeFromSuperview()
                    subtitleLabel = nil
                }
            }

            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds

        if let actionView = lazyActionView {
            actionView.frame = CGRect(x: bounds.maxX - bounds.height,
                                      y: bounds.minY,
                                      width: bounds.height,
                                      height: bounds.height)
        }

        switch layout {
        case .largeIconTitleSubtitle:
            layoutLargeIconTitleSubtitle()
        case .smallIconTitleSubtitle:
            layoutSmallIconTitleSubtitle()
        case .singleTitle:
            layoutSingleTitle()
        }
    }

    private func layoutLargeIconTitleSubtitle() {
        let titleHeight = titleLabel.intrinsicContentSize.height

        let iconOffset = lazyIconView != nil ? 2.0 * iconRadius + horizontalSpacing : 0.0
        let labelX = bounds.minX + contentInsets.left + iconOffset

        let trailing = lazyActionView?.frame.minX ?? bounds.maxX - contentInsets.right
        titleLabel.frame = CGRect(x: labelX,
                                  y: bounds.minY + contentInsets.top,
                                  width: trailing - labelX,
                                  height: titleHeight)

        let subtitleHeight = subtitleLabel?.intrinsicContentSize.height ?? 0.0
        subtitleLabel?.frame = CGRect(x: labelX,
                                     y: bounds.maxY - contentInsets.bottom - subtitleHeight,
                                     width: trailing - labelX,
                                     height: subtitleHeight)

        if let iconView = lazyIconView {
            iconView.frame = CGRect(x: bounds.minX + contentInsets.left,
                                    y: bounds.midY - iconRadius,
                                    width: 2.0 * iconRadius,
                                    height: 2.0 * iconRadius)
        }
    }

    private func layoutSmallIconTitleSubtitle() {
        let titleHeight = titleLabel.intrinsicContentSize.height
        let titleX = bounds.minX + contentInsets.left

        let trailing = lazyActionView?.frame.minX ?? bounds.maxX - contentInsets.right
        titleLabel.frame = CGRect(x: titleX,
                                  y: bounds.minY + contentInsets.top,
                                  width: trailing - titleX,
                                  height: titleHeight)

        let subtitleHeight = subtitleLabel?.intrinsicContentSize.height ?? 0.0
        let subtitleX = lazyIconView != nil ? titleX + 2.0 * iconRadius + horizontalSpacing : titleX
        subtitleLabel?.frame = CGRect(x: subtitleX,
                                      y: bounds.maxY - contentInsets.bottom - subtitleHeight,
                                      width: trailing - subtitleX,
                                      height: subtitleHeight)

        if let iconView = lazyIconView {
            let subtitleCenter = subtitleLabel?.frame.midY ?? bounds.midY
            iconView.frame = CGRect(x: titleX,
                                    y: subtitleCenter - iconRadius,
                                    width: 2.0 * iconRadius,
                                    height: 2.0 * iconRadius)
        }
    }

    private func layoutSingleTitle() {
        let titleHeight = titleLabel.intrinsicContentSize.height

        let iconOffset = lazyIconView != nil ? 2.0 * iconRadius + horizontalSpacing : 0.0
        let labelX = bounds.minX + contentInsets.left + iconOffset
        let trailing = lazyActionView?.frame.minX ?? bounds.maxX - contentInsets.right

        titleLabel.frame = CGRect(x: labelX,
                                  y: bounds.midY - titleHeight / 2.0,
                                  width: trailing - labelX,
                                  height: titleHeight)

        if let iconView = lazyIconView {
            iconView.frame = CGRect(x: bounds.minX + contentInsets.left,
                                    y: bounds.midY - iconRadius,
                                    width: 2.0 * iconRadius,
                                    height: 2.0 * iconRadius)
        }
    }

    private func configure() {
        self.backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureContentViewIfNeeded()
    }

    private func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            let triangularedView = RoundedView()
            triangularedView.isUserInteractionEnabled = false
            triangularedView.shadowOpacity = 0.0

            self.backgroundView = triangularedView
        }
    }

    private func lazyActionViewOrCreateIfNeeded() -> UIImageView {
        if let actionButton = lazyActionView {
            return actionButton
        }

        let imageView = UIImageView()
        imageView.contentMode = .center
        contentView?.addSubview(imageView)

        lazyActionView = imageView

        if superview != nil {
            setNeedsLayout()
        }

        return imageView
    }

    private func lazyIconViewOrCreateIfNeeded() -> UIImageView {
        if let iconView = lazyIconView {
            return iconView
        }

        let imageView = UIImageView()
        contentView?.addSubview(imageView)

        lazyIconView = imageView

        if superview != nil {
            setNeedsLayout()
        }

        return imageView
    }

    private func configureContentViewIfNeeded() {
        if contentView == nil {
            let contentView = UIView()
            contentView.backgroundColor = .clear
            contentView.isUserInteractionEnabled = false
            self.contentView = contentView
        }

        if titleLabel == nil {
            titleLabel = UILabel()
            contentView?.addSubview(titleLabel)
        }

        if subtitleLabel == nil, layout != .singleTitle {
            let label = UILabel()
            contentView?.addSubview(label)
            subtitleLabel = label
        }
    }
}
