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

@IBDesignable
open class QRFrameView: UIView {
    private var frameOverlayLayer: CAShapeLayer!

    open var frameLayer: CALayer? {
        didSet {
            oldValue?.removeFromSuperlayer()

            if let currentLayer = frameLayer {
                layer.insertSublayer(currentLayer, below: frameOverlayLayer)
                setNeedsLayout()
            }
        }
    }

    open var windowSize = CGSize(width: 100.0, height: 100.0) {
        didSet {
            updateOverlayWindow()
        }
    }

    open var windowPosition = CGPoint(x: 0.0, y: 0.0) {
        didSet {
            updateOverlayWindow()
        }
    }

    @IBInspectable
    open var cornerRadius: CGFloat = 10.0 {
        didSet {
            updateOverlayWindow()
        }
    }

    @IBInspectable
    open var fillColor: UIColor = UIColor.black.withAlphaComponent(0.5) {
        didSet {
            updateOverlayFillColor()
        }
    }

    // MARK: Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    private func configure() {
        if frameOverlayLayer == nil {
            frameOverlayLayer = CAShapeLayer()
            layer.addSublayer(frameOverlayLayer)
        }

        updateOverlayFillColor()
        updateOverlayWindow()
    }

    func updateOverlayFillColor() {
        frameOverlayLayer.fillColor = fillColor.cgColor
    }

    func updateOverlayWindow() {
        let origin = CGPoint(x: bounds.maxX * windowPosition.x - windowSize.width / 2.0,
                             y: windowPosition.y)
        let windowRect = CGRect(origin: origin, size: windowSize)
        let bezierPath = UIBezierPath(roundedRect: windowRect, cornerRadius: cornerRadius)
        bezierPath.append(UIBezierPath(rect: bounds))
        frameOverlayLayer.path = bezierPath.cgPath
        frameOverlayLayer.fillRule = .evenOdd
    }

    // MARK: Layout

    override open func layoutSubviews() {
        super.layoutSubviews()

        frameLayer?.frame = bounds

        if frameOverlayLayer?.frame != bounds {
            frameOverlayLayer?.frame = bounds
            updateOverlayWindow()
        }
    }
}

extension QRFrameView {
    @IBInspectable
    private var _windowWidth: CGFloat {
        get {
            return windowSize.width
        }

        set {
            windowSize = CGSize(width: newValue, height: windowSize.height)
        }
    }

    @IBInspectable
    private var _windowHeight: CGFloat {
        set {
            windowSize = CGSize(width: windowSize.width, height: newValue)
        }

        get {
            return windowSize.height
        }
    }

    @IBInspectable
    private var _windowPositionX: CGFloat {
        set {
            windowPosition = CGPoint(x: newValue, y: windowPosition.y)
        }

        get {
            return windowPosition.x
        }
    }

    @IBInspectable
    private var _windowPositionY: CGFloat {
        set {
            windowPosition = CGPoint(x: windowPosition.x, y: newValue)
        }

        get {
            return windowPosition.y
        }
    }
}
