import UIKit
import SoraUI
import SoraFoundation

final class ReferendumDetailsViewController: UIViewController, ControllerBackedProtocol, AdaptiveDesignable {
    struct Constants {
        static let detailsBottomSpacing: CGFloat = 16.0
    }

    var presenter: ReferendumDetailsPresenterProtocol!

    private(set) var votesButton: RoundedButton!
    private(set) var votesButtonHeightConstraint: NSLayoutConstraint?
    private(set) var votesButtonWidthConstraint: NSLayoutConstraint?

    @IBOutlet private(set) var scrollView: UIScrollView!
    @IBOutlet private(set) var imageView: UIImageView!
    @IBOutlet private(set) var remainedTitleLabel: UILabel!
    @IBOutlet private(set) var remainedDetailsLabel: UILabel!
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var detailsTextView: UITextView!
    @IBOutlet private(set) var resultTitleLabel: UILabel!
    @IBOutlet private(set) var resultIcon: UIImageView!
    @IBOutlet private(set) var resultDetailsLabel: UILabel!
    @IBOutlet private(set) var totalTitleLabel: UILabel!
    @IBOutlet private(set) var totalDetailsLabel: UILabel!
    @IBOutlet private(set) var supportTitleLabel: UILabel!
    @IBOutlet private(set) var unsupportTitleLabel: UILabel!
    @IBOutlet private(set) var mySupportTitleLabel: UILabel!
    @IBOutlet private(set) var myUnsupportTitleLabel: UILabel!
    @IBOutlet private(set) var progressView: ProgressView!
    @IBOutlet private(set) var supportVotesLabel: UILabel!
    @IBOutlet private(set) var unsupportVotesLabel: UILabel!
    @IBOutlet private(set) var mySupportVotesLabel: UILabel!
    @IBOutlet private(set) var myUnsupportVotesLabel: UILabel!
    @IBOutlet private(set) var supportVoteButton: RoundedButton!
    @IBOutlet private(set) var unsupportVoteButton: RoundedButton!
    @IBOutlet private(set) var leftTouchArea: RoundedButton!
    @IBOutlet private(set) var rightTouchArea: RoundedButton!

    @IBOutlet private(set) var openStateBottom: NSLayoutConstraint!
    @IBOutlet private(set) var finishedStateBottom: NSLayoutConstraint!
    @IBOutlet private(set) var votingResultEnabled: NSLayoutConstraint!
    @IBOutlet private(set) var votingResultDisabled: NSLayoutConstraint!
    @IBOutlet private(set) var mainImageHeight: NSLayoutConstraint!

    lazy var votesButtonFactory: VotesButtonFactoryProtocol.Type = VotesButtonFactory.self

    lazy var imageAppearanceAnimator: ViewAnimatorProtocol = TransitionAnimator(type: .fade)
    lazy var detailsAppearanceAnimator: ViewAnimatorProtocol = TransitionAnimator(type: .fade)
    lazy var changesAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()

    private(set) var mainImageSize = CGSize(width: 375.0, height: 213.0)

    private(set) var viewModel: ReferendumDetailsViewModelProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTopBar()
        configureScrollView()
        setupProgressView()
        setupLocalization()
        adjustLayout()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations

        supportTitleLabel.text = R.string.localizable
            .referendumSupportTitle(preferredLanguages: languages)

        unsupportTitleLabel.text = R.string.localizable
            .referendumUnsupportTitle(preferredLanguages: languages)

        supportVoteButton.imageWithTitleView?.title = ""
        supportVoteButton.invalidateLayout()

        unsupportVoteButton.imageWithTitleView?.title = ""
        unsupportVoteButton.invalidateLayout()

        supportTitleLabel.text = R.string.localizable
            .referendumSupportTitle(preferredLanguages: languages)

        unsupportTitleLabel.text = R.string.localizable
            .referendumUnsupportTitle(preferredLanguages: languages)

        resultTitleLabel.text = R.string.localizable
            .referendumVotingResult(preferredLanguages: languages)

        setupMySupportTitles(languages)
    }

    private func setupMySupportTitles(_ languages: [String]?) {
        let myVotesTitle = R.string.localizable
            .referendumMyVotesTitle(preferredLanguages: languages)

        let supportVoteTitle = R.string.localizable
            .referendumSupportTitle(preferredLanguages: languages)

        let unsupportVoteTitle = R.string.localizable
            .referendumUnsupportTitle(preferredLanguages: languages)

        let mySupportTitle = NSMutableAttributedString(string: myVotesTitle,
                                                       attributes: [
                                                        NSAttributedString.Key.foregroundColor: UIColor.silver,
                                                        NSAttributedString.Key.font: UIFont.referendumRegular
        ])

        mySupportTitle.append(NSAttributedString(string: " (\(supportVoteTitle))",
                                                attributes: [
                                                    NSAttributedString.Key.foregroundColor: UIColor.silver,
                                                    NSAttributedString.Key.font: UIFont.referendumVoting
        ]))

        mySupportTitleLabel.attributedText = mySupportTitle

        let myUnsupportTitle = NSMutableAttributedString(string: myVotesTitle,
                                                         attributes: [
                                                        NSAttributedString.Key.foregroundColor: UIColor.silver,
                                                        NSAttributedString.Key.font: UIFont.referendumRegular
        ])

        myUnsupportTitle.append(NSAttributedString(string: " (\(unsupportVoteTitle))",
                                                attributes: [
                                                    NSAttributedString.Key.foregroundColor: UIColor.silver,
                                                    NSAttributedString.Key.font: UIFont.referendumVoting
        ]))

        myUnsupportTitleLabel.attributedText = myUnsupportTitle
    }

    private func adjustLayout() {
        mainImageSize.width *= designScaleRatio.width
        mainImageSize.height *= designScaleRatio.width

        mainImageHeight.constant = mainImageSize.height

        detailsTextView.textContainer.lineFragmentPadding = 0
        detailsTextView.textContainerInset = .zero
    }

    private func setupProgressView() {
        progressView.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
    }

    private func setupTopBar() {
        setupCloseButton()
        setupVotesButton()
    }

    private func setupVotesButton() {
        votesButton = votesButtonFactory.createBarVotesButton()
        votesButton.addTarget(self,
                              action: #selector(actionOpenVotes(sender:)),
                              for: .touchUpInside)

        updateVotesButtonConstraints()

        let voteBarItem = UIBarButtonItem(customView: votesButton)
        navigationItem.rightBarButtonItem = voteBarItem
    }

    private func setupCloseButton() {
        let closeBarItem = UIBarButtonItem(image: R.image.iconClose(),
                                           style: .plain,
                                           target: self,
                                           action: #selector(actionClose))
        navigationItem.leftBarButtonItem = closeBarItem
    }

    private func configureScrollView() {
        scrollView.alpha = 0.0
    }

    private func updateVotesButtonConstraints() {
        let size = votesButton.intrinsicContentSize

        if #available(iOS 11.0, *) {
            votesButtonHeightConstraint?.isActive = false
            votesButtonHeightConstraint = votesButton.heightAnchor.constraint(equalToConstant: size.height)
            votesButtonHeightConstraint?.isActive = true

            votesButtonWidthConstraint?.isActive = false
            votesButtonWidthConstraint = votesButton.widthAnchor.constraint(equalToConstant: size.width)
            votesButtonWidthConstraint?.isActive = true
        } else {
            var frame = votesButton.frame
            frame.size.width = size.width
            frame.size.height = size.height
            votesButton.frame = frame
        }
    }

    @objc private func actionClose() {
        presenter.activateClose()
    }

    @objc private func actionOpenVotes(sender: AnyObject) {
        presenter.activateVotes()
    }

    @IBAction private func actionSuport(sender: AnyObject) {
        presenter.supportReferendum()
    }

    @IBAction private func actionUnsupport(sender: AnyObject) {
        presenter.unsupportReferendum()
    }
}

extension ReferendumDetailsViewController: ReferendumDetailsViewProtocol {
    private func preprocess(referendum: ReferendumDetailsViewModelProtocol) {
        if let mainImageViewModel = referendum.mainImageViewModel {
            mainImageViewModel.cornerRadius = 0.0
            mainImageViewModel.targetSize = mainImageSize
        }
    }

    func didReceive(votes: String) {
        votesButton.imageWithTitleView?.title = votes
        votesButton.invalidateLayout()
        updateVotesButtonConstraints()
    }

    func didReceive(referendum: ReferendumDetailsViewModelProtocol) {
        let oldViewModel = viewModel

        oldViewModel?.remainedTimeViewModel?.stop()

        preprocess(referendum: referendum)

        updateMainImage(referendum)
        updateRemainedTime(referendum)
        updateTextDetails(referendum)
        updateTotalVotes(referendum)
        updateCommonVotes(referendum)
        updateMyVotes(referendum)
        updateVotingResult(referendum)

        scrollView.alpha = 1.0
        view.setNeedsLayout()

        viewModel = referendum

        referendum.remainedTimeViewModel?.start(self)

        if oldViewModel == nil {
            detailsAppearanceAnimator.animate(view: scrollView, completionBlock: nil)
        }
    }
}

extension ReferendumDetailsViewController: TimerViewModelDelegate {
    func didStop(_ viewModel: TimerViewModelProtocol) {
        if let referendum = self.viewModel {
            updateRemainedTime(referendum)

            if let remainedTime = referendum.remainedTimeViewModel?.remainedSeconds, remainedTime <= 0.0 {
                presenter.handleElapsedTime()
            }
        }
    }

    func didChangeRemainedTime(_ viewModel: TimerViewModelProtocol) {
        if let referendum = self.viewModel {
            updateRemainedTime(referendum)
        }
    }

    func didStart(_ viewModel: TimerViewModelProtocol) {
        if let referendum = self.viewModel {
            updateRemainedTime(referendum)
        }
    }
}

extension ReferendumDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
