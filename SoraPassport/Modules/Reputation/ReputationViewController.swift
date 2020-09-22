/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI

final class ReputationViewController: UIViewController {
    enum HeaderMode {
        case hidden
        case empty
        case normal
    }

    enum DetailsMode {
        case hidden
        case normal
    }

	var presenter: ReputationPresenterProtocol!

    @IBOutlet private var reputationIconImageView: UIImageView!
    @IBOutlet private var rankTitleLabel: UILabel!
    @IBOutlet private var rankDetailsLabel: UILabel!
    @IBOutlet private var votesDetailsLabel: UILabel!
    @IBOutlet private var voteIconImageView: UIImageView!
    @IBOutlet private var voteContainerView: BorderedContainerView!
    @IBOutlet private var mainParagraphTitleLabel: UILabel!
    @IBOutlet private var mainParagraphDetailsLabel: UILabel!
    @IBOutlet private var emptyRankLabel: UILabel!
    @IBOutlet private var emptyRankBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var notEmptyRankBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var reputationDetailsContainerView: BorderedContainerView!
    @IBOutlet private var stepsTitleLabel: UILabel!
    @IBOutlet private var reputationStepsView: StepContainerView!
    @IBOutlet private var scrollView: UIScrollView!

    var transitionAnimator: BlockViewAnimator = BlockViewAnimator()

    private var didLayoutSetup: Bool = false

    private var headerMode: HeaderMode = .hidden

    var locale: Locale?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        apply(headerMode: .hidden)
        apply(detailsMode: .hidden)

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.viewDidAppear()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if !didLayoutSetup {
            applyHeaderConstraints(for: headerMode == .empty)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        didLayoutSetup = true
    }

    // MARK: Private

    private func setupLocalization() {
        title = R.string.localizable
            .reputationTitle(preferredLanguages: locale?.rLanguages)
        rankTitleLabel.text = R.string.localizable
            .reputationScreenYourCurrentReputation(preferredLanguages: locale?.rLanguages)
    }

    private func apply(headerMode: HeaderMode) {
        self.headerMode = headerMode

        switch headerMode {
        case .hidden:
            reputationIconImageView.alpha = 0.0
            rankTitleLabel.alpha = 0.0
            rankDetailsLabel.alpha = 0.0
            voteContainerView.alpha = 0.0
            emptyRankLabel.alpha = 0.0
        case .empty:
            reputationIconImageView.alpha = 1.0
            reputationIconImageView.image = R.image.iconsReputationEmpty()

            rankTitleLabel.alpha = 0.0
            rankDetailsLabel.alpha = 0.0
            voteContainerView.alpha = 0.0

            emptyRankLabel.alpha = 1.0

            if didLayoutSetup {
                applyHeaderConstraints(for: true)
            }

        case .normal:
            reputationIconImageView.alpha = 1.0
            reputationIconImageView.image = R.image.iconReputationTrophy()

            rankTitleLabel.alpha = 1.0
            rankDetailsLabel.alpha = 1.0
            voteContainerView.alpha = 1.0

            emptyRankLabel.alpha = 0.0

            if didLayoutSetup {
                applyHeaderConstraints(for: false)
            }
        }
    }

    private func apply(detailsMode: DetailsMode) {
        switch detailsMode {
        case .hidden:
            mainParagraphTitleLabel.alpha = 0.0
            mainParagraphDetailsLabel.alpha = 0.0
            reputationDetailsContainerView.alpha = 0.0
        case .normal:
            mainParagraphTitleLabel.alpha = 1.0
            mainParagraphDetailsLabel.alpha = 1.0
            reputationDetailsContainerView.alpha = 1.0
        }
    }

    private func applyHeaderConstraints(for isEmptyRank: Bool) {
        emptyRankBottomConstraint.isActive = isEmptyRank
        notEmptyRankBottomConstraint.isActive = !isEmptyRank
    }
}

extension ReputationViewController: ReputationViewProtocol {
    func set(emptyRankDetails: String) {
        transitionAnimator.animate(block: {
            self.emptyRankLabel.text = emptyRankDetails

            self.apply(headerMode: .empty)

            if self.didLayoutSetup {
                self.scrollView.layoutIfNeeded()
            }

        }, completionBlock: nil)
    }

    func set(existingRankDetails: String) {
        transitionAnimator.animate(block: {
            self.rankDetailsLabel.text = existingRankDetails

            self.apply(headerMode: .normal)

            if self.didLayoutSetup {
                self.scrollView.layoutIfNeeded()
            }

        }, completionBlock: nil)
    }

    func set(votesDetails: String) {
        votesDetailsLabel.text = votesDetails
    }

    func set(reputationDetailsViewModel: ReputationDetailsViewModel) {
        mainParagraphTitleLabel.text = reputationDetailsViewModel.mainTitle
        mainParagraphDetailsLabel.text = reputationDetailsViewModel.mainText
        stepsTitleLabel.text = reputationDetailsViewModel.stepsTitle
        reputationStepsView.bind(viewModels: reputationDetailsViewModel.steps)

        transitionAnimator.animate(block: {
            self.apply(detailsMode: .normal)
        }, completionBlock: nil)

    }
}
