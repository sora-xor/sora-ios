import UIKit

extension StepContainerView {
    @IBInspectable
    private var _horizontalSpacing: CGFloat {
        get {
            return horizontalSpacing
        }

        set {
            horizontalSpacing = newValue
        }
    }

    @IBInspectable
    private var _verticalSpacing: CGFloat {
        get {
            return verticalSpacing
        }

        set {
            verticalSpacing = newValue
        }
    }

    @IBInspectable
    private var _stepIndexFillColor: UIColor {
        get {
            return stepIndexFillColor
        }

        set {
            stepIndexFillColor = newValue
        }
    }

    @IBInspectable
    private var _stepIndexTitleColor: UIColor {
        get {
            return stepIndexTitleColor
        }

        set {
            stepIndexTitleColor = newValue
        }
    }

    @IBInspectable
    private var _stepIndexFontName: String {
        get {
            return stepIndexFont.fontName
        }

        set {
            let pointSize = stepIndexFont.pointSize

            guard let font = UIFont(name: newValue, size: pointSize) else {
                return
            }

            stepIndexFont = font
        }
    }

    @IBInspectable
    private var _stepIndexFontSize: CGFloat {
        get {
            return stepIndexFont.pointSize
        }

        set {
            let fontName = stepIndexFont.fontName
            guard let font = UIFont(name: fontName, size: newValue) else {
                return
            }

            stepIndexFont = font
        }
    }

    @IBInspectable
    private var _stepTitleColor: UIColor {
        get {
            return stepTitleColor
        }

        set {
            stepTitleColor = newValue
        }
    }

    @IBInspectable
    private var _stepTitleFontName: String {
        get {
            return stepTitleFont.fontName
        }

        set {
            let pointSize = stepTitleFont.pointSize

            guard let font = UIFont(name: newValue, size: pointSize) else {
                return
            }

            stepTitleFont = font
        }
    }

    @IBInspectable
    private var _stepTitleFontSize: CGFloat {
        get {
            return stepTitleFont.pointSize
        }

        set {
            let fontName = stepTitleFont.fontName
            guard let font = UIFont(name: fontName, size: newValue) else {
                return
            }

            stepTitleFont = font
        }
    }

    @IBInspectable
    private var _topStepIndexTitleInset: CGFloat {
        get {
            return stepIndexTitleInsets.top
        }

        set {
            var insets = stepIndexTitleInsets
            insets.top = newValue
            stepIndexTitleInsets = insets
        }
    }

    @IBInspectable
    private var _bottomStepIndexTitleInset: CGFloat {
        get {
            return stepIndexTitleInsets.bottom
        }

        set {
            var insets = stepIndexTitleInsets
            insets.bottom = newValue
            stepIndexTitleInsets = insets
        }
    }

    @IBInspectable
    private var _leftStepIndexTitleInset: CGFloat {
        get {
            return stepIndexTitleInsets.left
        }

        set {
            var insets = stepIndexTitleInsets
            insets.left = newValue
            stepIndexTitleInsets = insets
        }
    }

    @IBInspectable
    private var _rightStepIndexTitleInset: CGFloat {
        get {
            return stepIndexTitleInsets.right
        }

        set {
            var insets = stepIndexTitleInsets
            insets.right = newValue
            stepIndexTitleInsets = insets
        }
    }
}
