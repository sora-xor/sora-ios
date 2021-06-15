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
