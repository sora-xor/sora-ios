import UIKit

extension RoundedCellControlView {
    @IBInspectable
    private var _fillColor: UIColor {
        get {
            return roundedBackgroundView!.fillColor
        }

        set(newValue) {
            roundedBackgroundView!.fillColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedFillColor: UIColor {
        get {
            return roundedBackgroundView!.highlightedFillColor
        }

        set(newValue) {
            roundedBackgroundView!.highlightedFillColor = newValue
        }
    }

    @IBInspectable
    private var _strokeColor: UIColor {
        get {
            return roundedBackgroundView!.strokeColor
        }

        set(newValue) {
            roundedBackgroundView!.strokeColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedStrokeColor: UIColor {
        get {
            return roundedBackgroundView!.highlightedStrokeColor
        }

        set(newValue) {
            roundedBackgroundView!.highlightedStrokeColor = newValue
        }
    }

    @IBInspectable
    private var _strokeWidth: CGFloat {
        get {
            return roundedBackgroundView!.strokeWidth
        }

        set(newValue) {
            roundedBackgroundView!.strokeWidth = newValue
        }
    }

    @IBInspectable
    private var _icon: UIImage? {
        get {
            return titleAccessoryView.titleView.iconImage
        }

        set {
            titleAccessoryView.titleView.iconImage = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _highlightedIcon: UIImage? {
        get {
            return titleAccessoryView.titleView.highlightedIconImage
        }

        set {
            titleAccessoryView.titleView.highlightedIconImage = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _title: String? {
        get {
            return titleAccessoryView.titleView.title
        }

        set(newValue) {
            titleAccessoryView.titleView.title = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _titleColor: UIColor? {
        get {
            return titleAccessoryView.titleView.titleColor
        }

        set(newValue) {
            titleAccessoryView.titleView.titleColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedTitleColor: UIColor? {
        get {
            return titleAccessoryView.titleView.highlightedTitleColor
        }

        set(newValue) {
            titleAccessoryView.titleView.highlightedTitleColor = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        get {
            return titleAccessoryView.titleView.titleFont?.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                titleAccessoryView.titleView.titleFont = nil
                return
            }

            let pointSize = titleAccessoryView.titleView.titleFont?.pointSize ?? UIFont.labelFontSize
            titleAccessoryView.titleView.titleFont = UIFont(name: fontName, size: pointSize)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        get {
            return titleAccessoryView.titleView.titleFont?.pointSize ?? UIFont.labelFontSize
        }

        set(newValue) {
            let fontName = titleAccessoryView.titleView.titleFont?.fontName ?? UIFont
                .systemFont(ofSize: UIFont.labelFontSize).fontName
            titleAccessoryView.titleView.titleFont = UIFont(name: fontName, size: newValue)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _spacingBetweenLabelAndIcon: CGFloat {
        get {
            return titleAccessoryView.titleView.spacingBetweenLabelAndIcon
        }

        set {
            titleAccessoryView.titleView.spacingBetweenLabelAndIcon = newValue
        }
    }

    @IBInspectable
    private var _subtitle: String? {
        get {
            return titleAccessoryView.accessoryLabel.text
        }

        set(newValue) {
            titleAccessoryView.accessoryLabel.text = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _subtitleColor: UIColor? {
        get {
            return titleAccessoryView.accessoryLabel.textColor
        }

        set(newValue) {
            titleAccessoryView.accessoryLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedSubtitleColor: UIColor? {
        get {
            return titleAccessoryView.accessoryLabel.highlightedTextColor
        }

        set(newValue) {
            titleAccessoryView.accessoryLabel.highlightedTextColor = newValue
        }
    }

    @IBInspectable
    private var _subtitleFontName: String? {
        get {
            return titleAccessoryView.accessoryLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                titleAccessoryView.accessoryLabel.font = nil
                return
            }

            let pointSize = titleAccessoryView.accessoryLabel.font.pointSize
            titleAccessoryView.accessoryLabel.font = UIFont(name: fontName, size: pointSize)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _subtitleFontSize: CGFloat {
        get {
            return titleAccessoryView.accessoryLabel.font.pointSize
        }

        set(newValue) {
            let fontName = titleAccessoryView.accessoryLabel.font.fontName
            titleAccessoryView.accessoryLabel.font = UIFont(name: fontName, size: newValue)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _shadowColor: UIColor {
        get {
            return self.roundedBackgroundView!.shadowColor
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowColor = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var _shadowOffset: CGSize {
        get {
            return self.roundedBackgroundView!.shadowOffset
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowOffset = newValue
        }
    }

    @IBInspectable
    private var _shadowRadius: CGFloat {
        get {
            return self.roundedBackgroundView!.shadowRadius
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowRadius = newValue
        }
    }

    @IBInspectable
    private var _shadowOpacity: Float {
        get {
            return self.roundedBackgroundView!.shadowOpacity
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowOpacity = newValue
        }
    }

    @IBInspectable
    private var _cornerRadius: CGFloat {
        get {
            return self.roundedBackgroundView!.cornerRadius
        }

        set(newValue) {
            self.roundedBackgroundView!.cornerRadius = newValue
        }
    }

    @IBInspectable
    private var _contentOpacityWhenHighlighted: CGFloat {
        get {
            return contentOpacityWhenHighlighted
        }

        set(newValue) {
            contentOpacityWhenHighlighted = newValue
        }
    }

    @IBInspectable
    private var _changesContentOpacityWhenHighlighted: Bool {
        get {
            return changesContentOpacityWhenHighlighted
        }

        set(newValue) {
            changesContentOpacityWhenHighlighted = newValue
        }
    }

    @IBInspectable
    private var _separatorColor: UIColor {
        get {
            return borderView.strokeColor
        }

        set {
            borderView.strokeColor = newValue
        }
    }

    @IBInspectable
    private var _separatorWidth: CGFloat {
        get {
            return borderView.strokeWidth
        }

        set {
            borderView.strokeWidth = newValue
        }
    }
}
