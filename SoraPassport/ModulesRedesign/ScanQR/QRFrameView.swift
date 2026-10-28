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
