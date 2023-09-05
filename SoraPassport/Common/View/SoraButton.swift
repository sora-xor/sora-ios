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

class SoraButton: RoundedButton {

    @objc dynamic public var titleFont: UIFont? {
        get { return imageWithTitleView?.titleFont }
        set(newValue) {
            imageWithTitleView?.titleFont = newValue
            invalidateLayout()
        }
    }

    @objc dynamic public var cornerRadius: NSNumber? {
        get { return (roundedBackgroundView?.cornerRadius ?? 0) as NSNumber }
        set(newValue) {
            roundedBackgroundView?.cornerRadius = CGFloat(truncating: newValue ?? 0)
            invalidateLayout()
        }
    }

    @objc dynamic public var shadowOpacity: NSNumber? {
        get { return (roundedBackgroundView?.shadowOpacity ?? 0) as NSNumber }
        set(newValue) {
            roundedBackgroundView?.shadowOpacity = Float(truncating: newValue ?? 0)
            invalidateLayout()
        }

    }

    public var fillColor: UIColor {
        get { return roundedBackgroundView!.fillColor }
        set(newValue) {
            roundedBackgroundView?.fillColor = newValue
            invalidateLayout()
        }
    }

    public var title: String? {
        get { return imageWithTitleView?.title }
        set(newValue) {
            imageWithTitleView?.title = newValue
            invalidateLayout()
        }
    }

    public func startProgress() {
        self.addSubview(progressCover)
        progressCover.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        progressCover.heightAnchor.constraint(equalTo: self.heightAnchor).isActive = true
        progressCover.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        progressCover.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        self.isUserInteractionEnabled = false
        startAnimating()
    }

    public func stopProgress() {
        stopAnimating()
        progressCover.removeFromSuperview()
        self.isUserInteractionEnabled = true
    }

    private lazy var progressCover: ButtonProgressCover = {
        let view = ButtonProgressCover()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.cornerRadius = self.roundedBackgroundView!.cornerRadius
        view.shadowOpacity = 0
        view.shadowColor = .clear
        view.fillColor = R.color.baseDisabled()!
        view.progressIcon.loopMode = .loop
        return view
    }()
}

extension SoraButton {

    private func startAnimating() {
        progressCover.progressIcon.play()
    }

    private func stopAnimating() {
        progressCover.progressIcon.stop()
    }
}

import Lottie
class ButtonProgressCover: RoundedView {
    lazy var progressIcon: LottieAnimationView = LottieAnimationView(filePath: R.file.soraLoaderJson.path()!)

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

    internal override func configure() {
        super.configure()
        self.addSubview(progressIcon)
        progressIcon.translatesAutoresizingMaskIntoConstraints = false
        progressIcon.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        progressIcon.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        progressIcon.heightAnchor.constraint(lessThanOrEqualTo: self.heightAnchor, constant: -16).isActive = true
    }
}

final class GrayCopyButton: SoraButton {
    override func configure() {
        super.configure()

        self.imageWithTitleView?.layoutType = .horizontalLabelFirst
        self.imageWithTitleView?.iconImage = R.image.copy()!
        self.imageWithTitleView?.titleColor = R.color.baseContentPrimary()
        self.imageWithTitleView?.spacingBetweenLabelAndIcon = 7
    }

    override public var title: String? {
        get { return self.imageWithTitleView?.title }
        set { self.imageWithTitleView?.title = (newValue ?? "" ).soraConcat
            invalidateLayout()
        }
    }
}
