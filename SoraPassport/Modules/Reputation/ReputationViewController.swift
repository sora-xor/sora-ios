/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

final class ReputationViewController: UIViewController {
	var presenter: ReputationPresenterProtocol!

    @IBOutlet private var rankDetailsLabel: UILabel!
    @IBOutlet private var votesDetailsLabel: UILabel!
    @IBOutlet private var voteIconImageView: UIImageView!

    var appearanceAnimator: ViewAnimatorProtocol = TransitionAnimator(type: .fade)

    override func viewDidLoad() {
        super.viewDidLoad()

        hideRankDetails()
        hideVotesDetails()

        presenter.viewIsReady()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.viewDidAppear()
    }

    private func hideRankDetails() {
        rankDetailsLabel.isHidden = true
    }

    private func hideVotesDetails() {
        votesDetailsLabel.isHidden = true
        voteIconImageView.isHidden = true
    }

    private func showRankDetails(animated: Bool) {
        rankDetailsLabel.isHidden = false

        if animated {
            appearanceAnimator.animate(view: rankDetailsLabel, completionBlock: nil)
        }
    }

    private func showVoteDetails(animated: Bool) {
        votesDetailsLabel.isHidden = false
        voteIconImageView.isHidden = false

        if animated {
            appearanceAnimator.animate(view: votesDetailsLabel, completionBlock: nil)
            appearanceAnimator.animate(view: voteIconImageView, completionBlock: nil)
        }
    }
}

extension ReputationViewController: ReputationViewProtocol {
    func didReceiveRank(details: String) {
        rankDetailsLabel.text = details

        showRankDetails(animated: true)
    }

    func didReceiveVotes(details: String) {
        votesDetailsLabel.text = details

        showVoteDetails(animated: true)
    }
}
