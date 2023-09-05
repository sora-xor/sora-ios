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
import Anchorage
import SoraUI
import Then

@IBDesignable
final class LinkView: BackgroundedContentControl {

    private lazy var descriptionTitleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph1, isBold: true)
            $0.textColor = R.color.baseContentPrimary()
            $0.lineBreakMode = .byTruncatingTail
        }
    }()

    private lazy var linkTitleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph3)
            $0.textColor = R.color.neumorphism.textDark()
            $0.lineBreakMode = .byTruncatingTail
        }
    }()

    private lazy var iconImageView: UIImageView = {
        UIImageView(image: nil).then {
            $0.widthAnchor == 24
            $0.contentMode = .center
        }
    }()

    private lazy var arrowImageView: UIImageView = {
        UIImageView(image: R.image.arrowTopRight()).then {
            $0.widthAnchor == 16
            $0.contentMode = .center
        }
    }()

    private var separatorIsVisible: Bool = false

    init(separatorIsVisible: Bool = false) {
        self.separatorIsVisible = separatorIsVisible
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    override var isHighlighted: Bool {
        get {
            return super.isHighlighted
        }

        set {
            let oldValue = super.isHighlighted
            super.isHighlighted = newValue

            if !oldValue, newValue {
                layer.removeAllAnimations()
                alpha = 0.5
            }

            if oldValue, !newValue {
                layer.removeAllAnimations()
                alpha = 1.0
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let currentContentView = contentView else { return }

        let contentSize = CGSize(
            width: bounds.size.width, height: bounds.size.height
        )

        currentContentView.frame = CGRect(
            origin: .zero, size: contentSize
        )
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        configure()

        titleAttributedText = R.string.localizable.comingSoon()
        linkTitleAttributedText = R.string.localizable.stakingComingSoon()
    }
}

private extension LinkView {

    func configure() {
        backgroundColor = R.color.baseBackground()!

        changesContentOpacityWhenHighlighted = true

        contentView = contentView ?? createContentStackView()

        contentView?.do {
            $0.isUserInteractionEnabled = false
            $0.edgeAnchors == edgeAnchors
        }
    }

    func createContentStackView() -> UIView {
        UIStackView(arrangedSubviews: [
            UIStackView(arrangedSubviews: [
                // icon image
                iconImageView,
                // labels
                UIView().then {
                    let labelsStackView = UIStackView(arrangedSubviews: [
                        descriptionTitleLabel,
                        linkTitleLabel
                    ]).then {
                        $0.axis = .vertical
                    }

                    $0.backgroundColor = .clear
                    $0.addSubview(labelsStackView)
                    labelsStackView.horizontalAnchors == $0.horizontalAnchors
                    labelsStackView.centerYAnchor == $0.centerYAnchor
                },
                // arrow image
                arrowImageView
            ]).then {
                $0.axis = .horizontal
                $0.spacing = 20
            },
            // separator
            UIView().then {
                $0.isHidden = !separatorIsVisible
                $0.backgroundColor = R.color.neumorphism.tableSeparator()!
                $0.heightAnchor == 0.5
            }
        ]).then {
            $0.axis = .vertical
            $0.spacing = 0
            $0.heightAnchor == 56
        }
    }
}

extension LinkView {

    @IBInspectable
    var iconImage: UIImage? {
        get { iconImageView.image }
        set { iconImageView.image = newValue }
    }

    @IBInspectable
    var iconTintColor: UIColor! {
        get { iconImageView.tintColor }
        set { iconImageView.tintColor = newValue }
    }

    @IBInspectable
    var titleText: String? {
        get { descriptionTitleLabel.text }
        set { descriptionTitleLabel.text = newValue }
    }

    @IBInspectable
    var linkTitleText: String? {
        get { linkTitleLabel.text }
        set { linkTitleLabel.text = newValue }
    }

    @IBInspectable
    var titleAttributedText: String? {
        get { descriptionTitleLabel.attributedText?.string }
        set { descriptionTitleLabel.attributedText = newValue?.styled(.paragraph2) }
    }

    @IBInspectable
    var linkTitleAttributedText: String? {
        get { linkTitleLabel.attributedText?.string }
        set {
            let attributedNewValue = newValue?.styled(.paragraph3) ?? NSAttributedString(string: "")
            let mutableNewValue = NSMutableAttributedString(attributedString: attributedNewValue)
            mutableNewValue.addAttribute(.underlineStyle, value: 1, range: NSRange(location: 0, length: mutableNewValue.length))
            linkTitleLabel.attributedText = mutableNewValue
        }
    }
}
