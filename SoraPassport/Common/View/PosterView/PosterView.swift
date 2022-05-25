import UIKit
import SoraUI

protocol PosterViewDelegate: class {
    func didSelectPoster(view: PosterView)
}

final class PosterView: UIView {
    @IBOutlet private(set) var topRoundedView: RoundedView!
    @IBOutlet private(set) var bottomRoundedView: RoundedView!
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var detailsLabel: UILabel!
    @IBOutlet private(set) var contentView: UIView!

    @IBOutlet private var leadingConstraint: NSLayoutConstraint!
    @IBOutlet private var trallingConstraint: NSLayoutConstraint!
    @IBOutlet private var topConstraint: NSLayoutConstraint!
    @IBOutlet private var bottomConstraint: NSLayoutConstraint!

    @IBOutlet private var titleLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private var titleTrallingConstraint: NSLayoutConstraint!
    @IBOutlet private var titleTopConstraint: NSLayoutConstraint!
    @IBOutlet private var titleBottomConstraint: NSLayoutConstraint!

    @IBOutlet private var detailsLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private var detailsTrallingConstraint: NSLayoutConstraint!
    @IBOutlet private var detailsTopConstraint: NSLayoutConstraint!

    lazy var highlightedOnAnimation: ViewAnimatorProtocol = TransformAnimator.highlightedOn
    lazy var highlightedOffAnimation: ViewAnimatorProtocol = TransformAnimator.highlightedOff

    private var touchInProgress: Bool = false

    weak var delegate: PosterViewDelegate?

    var viewModel: PosterViewModelProtocol?

    var contentInsets: UIEdgeInsets {
        get {
            return UIEdgeInsets(top: topConstraint.constant,
                                left: leadingConstraint.constant,
                                bottom: -bottomConstraint.constant,
                                right: -trallingConstraint.constant)
        }

        set {
            topConstraint.constant = newValue.top
            bottomConstraint.constant = -newValue.bottom
            leadingConstraint.constant = newValue.left
            trallingConstraint.constant = -newValue.right

            setNeedsLayout()
        }
    }

    var titleInsets: UIEdgeInsets {
        get {
            return UIEdgeInsets(top: titleTopConstraint.constant,
                                left: titleLeadingConstraint.constant,
                                bottom: -titleBottomConstraint.constant,
                                right: -titleTrallingConstraint.constant)
        }

        set {
            titleLeadingConstraint.constant = newValue.left
            titleTrallingConstraint.constant = -newValue.right
            titleTopConstraint.constant = newValue.top
            titleBottomConstraint.constant = -newValue.bottom

            setNeedsLayout()
        }
    }

    var detailsInsets: UIEdgeInsets {
        get {
            return UIEdgeInsets(top: detailsTopConstraint.constant,
                                left: detailsLeadingConstraint.constant,
                                bottom: 0.0,
                                right: -detailsTrallingConstraint.constant)
        }

        set {
            detailsTopConstraint.constant = newValue.top
            detailsLeadingConstraint.constant = newValue.left
            detailsTrallingConstraint.constant = -newValue.right

            setNeedsLayout()
        }
    }

    func bind(viewModel: PosterViewModelProtocol) {
        self.viewModel = viewModel

        titleLabel.attributedText = viewModel.content.title
        detailsLabel.attributedText = viewModel.content.details
    }

    @IBAction private func actionLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        let location =  gestureRecognizer.location(in: self)
        switch gestureRecognizer.state {
        case .began:
            layer.removeAllAnimations()
            highlightedOnAnimation.animate(view: contentView, completionBlock: nil)
            touchInProgress = true
        case .changed:
            if !contentView.frame.contains(location), touchInProgress {
                touchInProgress = false
                layer.removeAllAnimations()
                highlightedOffAnimation.animate(view: contentView, completionBlock: nil)
            }
        case .ended:
            if contentView.frame.contains(location), touchInProgress {
                touchInProgress = false
                layer.removeAllAnimations()
                highlightedOffAnimation.animate(view: contentView, completionBlock: nil)

                delegate?.didSelectPoster(view: self)
            }
        case .cancelled:
            if touchInProgress {
                touchInProgress = false

                layer.removeAllAnimations()
                highlightedOffAnimation.animate(view: contentView, completionBlock: nil)
            }

        default:
            break
        }
    }
}
