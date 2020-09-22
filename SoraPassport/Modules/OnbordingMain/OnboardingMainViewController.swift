import UIKit
import SoraUI

final class OnboardingMainViewController: UIViewController, AdaptiveDesignable, HiddableBarWhenPushed {
    private struct Constants {
        static let tutorialItemSizeWidth: CGFloat = 375.0
        static let restoreBottomFriction: CGFloat = 0.9
        static let signupBottomFriction: CGFloat = 0.9
        static let tutorialDecreasingFriction: CGFloat = 0.95
        static let tutorialIncreasingFriction: CGFloat = 0.95
    }

    var presenter: OnboardingMainPresenterProtocol!

    @IBOutlet private var tutorialCollectionView: UICollectionView!
    @IBOutlet private var pageControl: UIPageControl!
    @IBOutlet private var termsLabel: UILabel!
    @IBOutlet private var signUpButton: RoundedButton!
    @IBOutlet private var restoreButton: RoundedButton!

    @IBOutlet private var collectionViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private var collectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var restoreBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var signupBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var termsBottomConstraint: NSLayoutConstraint!

    var locale: Locale?

    var termDecorator: AttributedStringDecoratorProtocol?

    private(set) var viewModels: [TutorialViewModelProtocol] = [] {
        didSet {
            pageControl.numberOfPages = viewModels.count
            pageControl.currentPage = 0

            tutorialCollectionView.reloadData()
        }
    }

    // MARK: Appearance

    override func viewDidLoad() {
        super.viewDidLoad()

        configurePageControl()
        configureCollectionView()
        setupLocalization()
        configureTermsLabel()
        adjustLayout()

        presenter.setup()
    }

    private func configureCollectionView() {
        tutorialCollectionView.register(R.nib.tutorialCollectionViewCell)

        automaticallyAdjustsScrollViewInsets = false
    }

    private func configurePageControl() {
        pageControl.numberOfPages = 0
    }

    private func configureTermsLabel() {
        if let attributedText = termsLabel.attributedText {
            termsLabel.attributedText = termDecorator?.decorate(attributedString: attributedText)
        }
    }

    private func setupLocalization() {
        signUpButton.imageWithTitleView?.title = R.string.localizable
            .tutorialSignUp(preferredLanguages: locale?.rLanguages)
        restoreButton.imageWithTitleView?.title = R.string.localizable
            .tutorialRestoreAccount(preferredLanguages: locale?.rLanguages)

        let text = NSAttributedString(string: R.string.localizable
            .tutorialTermsAndConditions1(preferredLanguages: locale?.rLanguages))
        termsLabel.attributedText = text
    }

    private func adjustLayout() {
        collectionViewTopConstraint.constant = UIApplication.shared.statusBarFrame.size.height

        if isAdaptiveHeightDecreased {
            collectionViewHeightConstraint.constant *= designScaleRatio.height *
                Constants.tutorialDecreasingFriction
            restoreBottomConstraint.constant *= designScaleRatio.height
            signupBottomConstraint.constant *= designScaleRatio.height
        }

        if isAdaptiveHeightIncreased {
            collectionViewHeightConstraint.constant *= designScaleRatio.height *
                Constants.tutorialIncreasingFriction
            restoreBottomConstraint.constant *= designScaleRatio.height * Constants.restoreBottomFriction
            signupBottomConstraint.constant *= designScaleRatio.height * Constants.signupBottomFriction
        }

        termsBottomConstraint.constant *= designScaleRatio.height
    }

    // MARK: Action

    @IBAction private func actionSignup(sender: AnyObject) {
        presenter.activateSignup()
    }

    @IBAction private func actionRestoreAccess(sender: AnyObject) {
        presenter.activateAccountRestore()
    }

    @IBAction private func actionPageControlChange(sender: AnyObject) {
        let newContentOffset = CGPoint(x: CGFloat(pageControl.currentPage) * tutorialCollectionView.frame.size.width,
                                       y: tutorialCollectionView.contentOffset.y)
        tutorialCollectionView.setContentOffset(newContentOffset, animated: true)
    }

    @IBAction private func actionTerms(gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            let location = gestureRecognizer.location(in: termsLabel.superview)

            if location.x < termsLabel.center.x {
                presenter.activateTerms()
            } else {
                presenter.activatePrivacy()
            }

        }
    }
}

extension OnboardingMainViewController: UIScrollViewDelegate {
    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard pageControl.numberOfPages > 0 else {
            return
        }

        let newPage = Int(floor(targetContentOffset.pointee.x / scrollView.frame.size.width))
        pageControl.currentPage = max(min(newPage, pageControl.numberOfPages), 0)
    }
}

extension OnboardingMainViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModels.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.tutorialCellId,
                                                      for: indexPath)!

        cell.bind(viewModel: viewModels[indexPath.row])

        return cell
    }
}

extension OnboardingMainViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.size.width,
                      height: floor(collectionViewHeightConstraint.constant))
    }
}

extension OnboardingMainViewController: OnboardingMainViewProtocol {
    func didReceive(viewModels: [TutorialViewModelProtocol]) {
        self.viewModels = viewModels
    }
}
