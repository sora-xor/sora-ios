/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

extension StepContainerView {
    @IBInspectable
    private var _horizontalSpacing: CGFloat {
        set {
            horizontalSpacing = newValue
        }

        get {
            return horizontalSpacing
        }
    }

    @IBInspectable
    private var _verticalSpacing: CGFloat {
        set {
            verticalSpacing = newValue
        }

        get {
            return verticalSpacing
        }
    }

    @IBInspectable
    private var _stepIndexFillColor: UIColor {
        set {
            stepIndexFillColor = newValue
        }

        get {
            return stepIndexFillColor
        }
    }

    @IBInspectable
    private var _stepIndexTitleColor: UIColor {
        set {
            stepIndexTitleColor = newValue
        }

        get {
            return stepIndexTitleColor
        }
    }

    @IBInspectable
    private var _stepIndexFontName: String {
        set {
            let pointSize = stepIndexFont.pointSize

            guard let font = UIFont(name: newValue, size: pointSize) else {
                return
            }

            stepIndexFont = font
        }

        get {
            return stepIndexFont.fontName
        }
    }

    @IBInspectable
    private var _stepIndexFontSize: CGFloat {
        set {
            let fontName = stepIndexFont.fontName
            guard let font = UIFont(name: fontName, size: newValue) else {
                return
            }

            stepIndexFont = font
        }

        get {
            return stepIndexFont.pointSize
        }
    }

    @IBInspectable
    private var _stepTitleColor: UIColor {
        set {
            stepTitleColor = newValue
        }

        get {
            return stepTitleColor
        }
    }

    @IBInspectable
    private var _stepTitleFontName: String {
        set {
            let pointSize = stepTitleFont.pointSize

            guard let font = UIFont(name: newValue, size: pointSize) else {
                return
            }

            stepTitleFont = font
        }

        get {
            return stepTitleFont.fontName
        }
    }

    @IBInspectable
    private var _stepTitleFontSize: CGFloat {
        set {
            let fontName = stepTitleFont.fontName
            guard let font = UIFont(name: fontName, size: newValue) else {
                return
            }

            stepTitleFont = font
        }

        get {
            return stepTitleFont.pointSize
        }
    }

    @IBInspectable
    private var _topStepIndexTitleInset: CGFloat {
        set {
            var insets = stepIndexTitleInsets
            insets.top = newValue
            stepIndexTitleInsets = insets
        }

        get {
            return stepIndexTitleInsets.top
        }
    }

    @IBInspectable
    private var _bottomStepIndexTitleInset: CGFloat {
        set {
            var insets = stepIndexTitleInsets
            insets.bottom = newValue
            stepIndexTitleInsets = insets
        }

        get {
            return stepIndexTitleInsets.bottom
        }
    }

    @IBInspectable
    private var _leftStepIndexTitleInset: CGFloat {
        set {
            var insets = stepIndexTitleInsets
            insets.left = newValue
            stepIndexTitleInsets = insets
        }

        get {
            return stepIndexTitleInsets.left
        }
    }

    @IBInspectable
    private var _rightStepIndexTitleInset: CGFloat {
        set {
            var insets = stepIndexTitleInsets
            insets.right = newValue
            stepIndexTitleInsets = insets
        }

        get {
            return stepIndexTitleInsets.right
        }
    }
}
