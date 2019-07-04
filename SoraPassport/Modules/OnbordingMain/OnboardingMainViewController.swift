/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

final class OnboardingMainViewController: UIViewController, AdaptiveDesignable, HiddableBarWhenPushed {
    private struct Constants {
        static let tutorialItemSizeWidth: CGFloat = 375.0
        static let restoreBottomFriction: CGFloat = 0.75
        static let signupBottomFriction: CGFloat = 0.75
    }

    var presenter: OnboardingMainPresenterProtocol!

    @IBOutlet private var tutorialCollectionView: UICollectionView!
    @IBOutlet private var pageControl: UIPageControl!
    @IBOutlet private var termsLabel: UILabel!

    @IBOutlet private var collectionViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private var collectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var restoreBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var signupBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var termsBottomConstraint: NSLayoutConstraint!

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
        configureTermsLabel()
        adjustLayout()

        presenter.viewIsReady()
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

    private func adjustLayout() {
        collectionViewTopConstraint.constant = UIApplication.shared.statusBarFrame.size.height

        collectionViewHeightConstraint.constant *= designScaleRatio.height

        if isAdaptiveHeightDecreased {
            restoreBottomConstraint.constant *= designScaleRatio.height * Constants.restoreBottomFriction
            signupBottomConstraint.constant *= designScaleRatio.height * Constants.signupBottomFriction
        } else {
            restoreBottomConstraint.constant *= designScaleRatio.height
            signupBottomConstraint.constant *= designScaleRatio.height
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
            presenter.activateTerms()
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
