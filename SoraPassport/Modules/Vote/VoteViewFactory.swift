import UIKit

protocol VoteViewFactoryProtocol {
    func createVoteViewController(with model: VoteViewModelProtocol,
                                  style: VoteViewStyle,
                                  delegate: VoteViewDelegate?) -> UIViewController?
}

class VoteViewFactory {
    private weak var transitioningDelegate: UIViewControllerTransitioningDelegate?

    init(transitioningDelegate: UIViewControllerTransitioningDelegate?) {
        self.transitioningDelegate = transitioningDelegate
    }
}

extension VoteViewFactory: VoteViewFactoryProtocol {
    func createVoteViewController(with model: VoteViewModelProtocol,
                                  style: VoteViewStyle,
                                  delegate: VoteViewDelegate?) -> UIViewController? {
        guard let view = UINib(resource: R.nib.voteView)
            .instantiate(withOwner: nil, options: nil).first as? VoteView else {
                return nil
        }

        view.normalDescriptionColor = R.color.baseContentPrimary()!
        view.errorDescriptionColor = R.color.statusError()!

        let trackCornerRadius: CGFloat = 4.0
        let trackImageSize = CGSize(width: 12.0, height: 8.0)
        let resizableInsets = UIEdgeInsets(top: 0.0,
                                           left: trackCornerRadius,
                                           bottom: 0.0,
                                           right: trackCornerRadius)
        let minimumTrackImage = UIImage.background(from: style.tintColor,
                                                   size: trackImageSize,
                                                   cornerRadius: trackCornerRadius,
                                                   contentScale: UIScreen.main.scale)
        view.minimumTrackImage = minimumTrackImage?.resizableImage(withCapInsets: resizableInsets)

        let maximumTrackImage = UIImage.background(from: R.color.statusSuccessBackground()!,
                                                   size: trackImageSize,
                                                   cornerRadius: trackCornerRadius,
                                                   contentScale: UIScreen.main.scale)
        view.maximumTrackImage = maximumTrackImage?.resizableImage(withCapInsets: resizableInsets)

        view.voteTitle = style.voteTitle
        view.voteIcon = style.voteIcon
        view.voteFillColor = style.tintColor
        view.voteHighlightedFillColor = style.tintColor
        view.sliderThumb = style.thumbIcon

        view.frame.size.width = min(UIScreen.main.bounds.size.width,
                                    UIScreen.main.bounds.size.height)
        view.delegate = delegate
        view.model = model

        let viewController = UIViewController()
        viewController.view = view
        viewController.transitioningDelegate = transitioningDelegate
        viewController.modalPresentationStyle = .custom

        return viewController
    }
}
