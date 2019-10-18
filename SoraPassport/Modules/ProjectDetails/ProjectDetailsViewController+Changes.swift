/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI

// MARK: Details Changes Logic

extension ProjectDetailsViewController {
    func applyChanges(since oldViewModel: ProjectDetailsViewModelProtocol?,
                      animated: Bool) {

        let changesBlock = {
            var hasLayoutChanges = false

            self.applyMainImage(since: oldViewModel)

            if self.applyProgressSectionChanges(since: oldViewModel, animated: animated) {
                hasLayoutChanges = true
            }

            if self.applyActionsSectionChanges(since: oldViewModel, animated: animated) {
                hasLayoutChanges = true
            }

            if self.applyRewardSectionChanges(since: oldViewModel, animated: animated) {
                hasLayoutChanges = true
            }

            if self.applyStatisticsSectionChanges(since: oldViewModel, animated: animated) {
                hasLayoutChanges = true
            }

            if self.applyDetailsSectionChanges(since: oldViewModel) {
                hasLayoutChanges = true
            }

            if self.applyGallerySectionChanges(since: oldViewModel) {
                hasLayoutChanges = true
            }

            self.applyContactsSectionChanges(from: oldViewModel)

            self.scrollView.alpha = self.viewModel != nil ? 1.0 : 0.0

            if hasLayoutChanges {
                self.scrollView.layoutIfNeeded()
            }
        }

        if animated {
            changesAnimator.animate(block: changesBlock,
                                    completionBlock: nil)
        } else {
            changesBlock()
        }
    }

    private func applyMainImage(since oldViewModel: ProjectDetailsViewModelProtocol?) {
        oldViewModel?.mainImageViewModel?.cancel()
        mainImageView.image = nil

        guard let viewModel = viewModel else {
            return
        }

        if let image = viewModel.mainImageViewModel?.image {
            mainImageView.image = image
            return
        }

        viewModel.mainImageViewModel?.loadImage { [weak self] (image, error) in
            guard error == nil else {
                return
            }

            guard let strongSelf = self else {
                return
            }

            strongSelf.mainImageView.image = image
            strongSelf.imageAppearanceAnimator.animate(view: strongSelf.mainImageView, completionBlock: nil)
        }
    }

    private func applyProgressSectionChanges(since oldViewModel: ProjectDetailsViewModelProtocol?,
                                             animated: Bool) -> Bool {
        guard let viewModel = viewModel else {
            return false
        }

        var hasLayoutChanges = false

        if oldViewModel?.title != viewModel.title {
            titleLabel.text = viewModel.title
            hasLayoutChanges = true
        }

        if applyFundingProgressChanges(since: oldViewModel, animated: animated) {
            hasLayoutChanges = true
        }

        return hasLayoutChanges
    }

    private func applyFundingProgressChanges(since oldViewModel: ProjectDetailsViewModelProtocol?,
                                             animated: Bool) -> Bool {
        guard let viewModel = viewModel else {
            return false
        }

        let prevProgressWidth = progressLabel.intrinsicContentSize.width + deadlineLabel.intrinsicContentSize.width
            + progressLabelTrallingWhenLong.constant

        var hasLayoutChanges = false

        if oldViewModel?.fundingDetails != viewModel.fundingDetails {
            progressLabel.text = viewModel.fundingDetails
            hasLayoutChanges = true
        }

        let remainDetails = viewModel.remainedTimeDetails.count > 0 ? viewModel.remainedTimeDetails : " "

        if oldViewModel?.remainedTimeDetails != remainDetails {
            deadlineLabel.text = remainDetails
            hasLayoutChanges = true
        }

        let oldProgressValue = oldViewModel?.fundingProgressValue ?? Float(progressView.progress)
        if abs(viewModel.fundingProgressValue - oldProgressValue) > 0.0 {
            progressView.setProgress(CGFloat(viewModel.fundingProgressValue), animated: animated)
            hasLayoutChanges = true
        }

        let progressWidth = progressLabel.intrinsicContentSize.width + deadlineLabel.intrinsicContentSize.width
            + progressLabelTrallingWhenLong.constant

        let shouldChangeLayout = (prevProgressWidth <= contentWidth) != (progressWidth <= contentWidth)

        if shouldChangeLayout {
            if progressWidth <= contentWidth {
                progressLabelTrallingWhenShort.isActive = true
                deadlineLabelTopWhenShort.isActive = true
                progressLabelTrallingWhenLong.isActive = false
                deadlineLabelTopWhenLong.isActive = false
                deadlineLabelLeftWhenLong.isActive = false
            } else {
                progressLabelTrallingWhenShort.isActive = false
                deadlineLabelTopWhenShort.isActive = false
                progressLabelTrallingWhenLong.isActive = true
                deadlineLabelTopWhenLong.isActive = true
                deadlineLabelLeftWhenLong.isActive = true
            }

            hasLayoutChanges = true
        }

        if viewModel.status.isFinished != oldViewModel?.status.isFinished {
            setProgressView(hidden: viewModel.status.isFinished)

            hasLayoutChanges = true
        }

        return hasLayoutChanges
    }

    private func applyActionsSectionChanges(since oldViewModel: ProjectDetailsViewModelProtocol?,
                                            animated: Bool) -> Bool {
        guard let viewModel = viewModel else {
            return false
        }

        let prevActionsWidth = voteButton.intrinsicContentSize.width + Constants.horizontalMinimumSpacing
            + favoriteButton.intrinsicContentSize.width

        var hasLayoutChanges = false

        if oldViewModel?.votingTitle != viewModel.votingTitle
            || viewModel.status.isFinished != oldViewModel?.status.isFinished {
            voteButton.imageWithTitleView?.title = viewModel.votingTitle

            switch viewModel.status {
            case .open:
                voteButton.roundedBackgroundView?.fillColor = .projectDetailsVoteBackgroundWhenOpen
                voteButton.imageWithTitleView?.titleColor = .projectDetailsVoteTitleWhenOpen
                voteButton.contentInsets.left = Constants.voteButtonInsetsWhenOpen
                voteButton.contentInsets.right = Constants.voteButtonInsetsWhenOpen

                if viewModel.isVoted {
                    voteButton.imageWithTitleView?.iconImage = R.image.voteWhiteButtonFilledIcon()
                } else {
                    voteButton.imageWithTitleView?.iconImage = R.image.voteWhiteButtonIcon()
                }

                voteButton.isUserInteractionEnabled = true
            case .finished(let isSuccessfull):
                voteButton.roundedBackgroundView?.fillColor = .projectDetailsVoteBackgroundWhenFinished
                voteButton.imageWithTitleView?.titleColor = .projectDetailsVoteTitleWhenFinished
                voteButton.contentInsets.left = Constants.voteButtonInsetsWhenFinished
                voteButton.contentInsets.right = Constants.voteButtonInsetsWhenFinished
                voteButton.imageWithTitleView?.iconImage = isSuccessfull ? R.image.successfullVotingIcon()
                    : R.image.unsuccessfulVotingIcon()
                voteButton.isUserInteractionEnabled = false
            }

            voteButton.invalidateLayout()

            hasLayoutChanges = true
        }

        if oldViewModel?.isFavorite != viewModel.isFavorite {
            setFavorite(viewModel.isFavorite)
            hasLayoutChanges = true
        }

        if updateActionsLayout(from: prevActionsWidth) {
            hasLayoutChanges = true
        }

        return hasLayoutChanges
    }

    private func applyRewardSectionChanges(since oldViewModel: ProjectDetailsViewModelProtocol?,
                                           animated: Bool) -> Bool {
        guard let viewModel = viewModel else {
            return false
        }

        var hasLayoutChanges = false

        if oldViewModel?.rewardDetails != viewModel.rewardDetails
            || oldViewModel?.status.isFinished != viewModel.status.isFinished {

            if let rewardDetails = viewModel.rewardDetails {
                rewardView.alpha = 1.0
                rewardLabel.text = rewardDetails

                switch viewModel.status {
                case .open:
                    rewardImageView.alpha = 1.0
                    rewardLabelLeading.constant = Constants.rewardLableLeftWhenSuccess
                case .finished(let isSuccess):
                    if isSuccess {
                        rewardImageView.alpha = 1.0
                        rewardLabelLeading.constant = Constants.rewardLableLeftWhenSuccess
                    } else {
                        rewardImageView.alpha = 0.0
                        rewardLabelLeading.constant = Constants.rewardLableLeftWhenFail
                    }
                }

            } else {
                rewardView.alpha = 0.0
            }

            hasLayoutChanges = true
        }

        return hasLayoutChanges
    }

    private func applyStatisticsSectionChanges(since oldViewModel: ProjectDetailsViewModelProtocol?,
                                               animated: Bool) -> Bool {
        guard let viewModel = viewModel else {
            return false
        }

        var hasLayoutChanges = false

        if oldViewModel == nil || (oldViewModel?.statisticsDetails != viewModel.statisticsDetails) {
            if let statistics = viewModel.statisticsDetails {
                statisticsView.alpha = 1.0
                statisticsLabel.text = statistics
            } else {
                statisticsView.alpha = 0.0
            }

            hasLayoutChanges = true
        }

        let shouldChangeLayout = (oldViewModel == nil) ||
            ((oldViewModel?.rewardDetails == nil) != (viewModel.rewardDetails == nil))

        if shouldChangeLayout {
            if viewModel.rewardDetails != nil {
                statisticsTopWithReward.isActive = true
                statisticsTopWithFavorite.isActive = false
            } else {
                statisticsTopWithReward.isActive = false
                statisticsTopWithFavorite.isActive = true
            }

            hasLayoutChanges = true
        }

        return hasLayoutChanges
    }

    private func applyDetailsSectionChanges(since oldViewModel: ProjectDetailsViewModelProtocol?) -> Bool {
        guard let viewModel = viewModel else {
            return false
        }

        var hasLayoutChanges = false

        if oldViewModel?.details != viewModel.details {
            updateDetailsViewHeight()
            setDetails(expanded: false)
            detailsTextViewHeight.constant = detailsCollapsedHeight

            hasLayoutChanges = true
        }

        let shouldChangeLayout = (oldViewModel == nil) ||
            ((oldViewModel?.rewardDetails == nil) != (viewModel.rewardDetails == nil)) ||
            ((oldViewModel?.statisticsDetails == nil) != (viewModel.statisticsDetails == nil))

        if shouldChangeLayout {
            if viewModel.statisticsDetails != nil {
                detailsTopWithStatistics.isActive = true
                detailsTopWithReward.isActive = false
                detailsTopWithFavorite.isActive = false
            } else if viewModel.rewardDetails != nil {
                detailsTopWithStatistics.isActive = false
                detailsTopWithReward.isActive = true
                detailsTopWithFavorite.isActive = false
            } else {
                detailsTopWithStatistics.isActive = false
                detailsTopWithReward.isActive = false
                detailsTopWithFavorite.isActive = true
            }
        }

        statisticsView.borderType = viewModel.rewardDetails != nil ? .top : .none

        return hasLayoutChanges
    }

    private func applyGallerySectionChanges(since oldViewModel: ProjectDetailsViewModelProtocol?) -> Bool {
        var hasGallery = false

        if let viewModel = viewModel, viewModel.galleryImageViewModels.count > 0 {
            hasGallery = true
        }

        setGallery(hidden: !hasGallery)

        galleryCollectionView.reloadData()

        return true
    }

    private func applyContactsSectionChanges(from oldViewModel: ProjectDetailsViewModelProtocol?) {
        if oldViewModel?.website != viewModel?.website {
            websiteButton.setTitle(viewModel?.website, for: .normal)
        }

        if oldViewModel?.email != viewModel?.email {
            emailButton.setTitle(viewModel?.email, for: .normal)
        }
    }

    func setFavorite(_ value: Bool) {
        if value {
            favoriteButton.imageWithTitleView?.title = R.string.localizable.projectDetailsFavoriteMarkedTitle()
            favoriteButton.imageWithTitleView?.iconImage = R.image.favoriteButtonIconSel()
        } else {
            favoriteButton.imageWithTitleView?.title = R.string.localizable.projectDetailsFavoriteNotMarkedTitle()
            favoriteButton.imageWithTitleView?.iconImage = R.image.favoriteButtonIcon()
        }

        favoriteButton.invalidateLayout()
    }

    private func setProgressView(hidden: Bool) {
        progressView.alpha = hidden ? 0.0 : 1.0

        voteButtonTopWhenOpen.isActive = !hidden
        voteButtonTopWhenFinished.isActive = hidden
    }

    private func setDetails(expanded: Bool) {
        detailsTextView.expanded = expanded
        detailsTextView.text = viewModel?.details
        detailsTextView.showsFooter = detailsExpandedHeight > detailsCollapsedHeight
    }

    private func updateActionsLayout(from previousActionWidth: CGFloat) -> Bool {
        var hasLayoutChanges = false

        let actionsWidth = voteButton.intrinsicContentSize.width + Constants.horizontalMinimumSpacing
            + favoriteButton.intrinsicContentSize.width

        let shouldChangeLayout = (previousActionWidth <= contentWidth) != (actionsWidth <= contentWidth)

        if shouldChangeLayout {
            if actionsWidth <= contentWidth {
                voteButtonLeftWhenShort.isActive = true
                favoriteButtonCenterYWhenShort.isActive = true
                favoriteButtonTrallingWhenShort.isActive = true
                voteButtonCenterWhenLong.isActive = false
                favoriteButtonTopWhenLong.isActive = false
                favoriteButtonCenterXWhenLong.isActive = false
            } else {
                voteButtonLeftWhenShort.isActive = false
                favoriteButtonCenterYWhenShort.isActive = false
                favoriteButtonTrallingWhenShort.isActive = false
                voteButtonCenterWhenLong.isActive = true
                favoriteButtonTopWhenLong.isActive = true
                favoriteButtonCenterXWhenLong.isActive = true
            }

            hasLayoutChanges = true
        }

        return hasLayoutChanges
    }

    private func updateDetailsViewHeight() {
        guard let text = viewModel?.details else {
            detailsExpandedHeight = detailsCollapsedHeight
            return
        }

        let boundingSize = CGSize(width: detailsTextView.frame.size.width, height: CGFloat.greatestFiniteMagnitude)
        detailsExpandedHeight = (text as NSString).boundingRect(with: boundingSize,
                                                                options: .usesLineFragmentOrigin,
                                                                attributes: [.font: detailsTextView.textFont],
                                                                context: nil).size.height
        detailsExpandedHeight += detailsTextView.footerHeight

        detailsCollapsedHeight = detailsExpandedHeight > Constants.detailsCollapsedHeight
            ? Constants.detailsCollapsedHeight : detailsExpandedHeight
    }

    private func setGallery(hidden: Bool) {
        galleryLabel.alpha = hidden ? 0.0 : 1.0
        galleryCollectionView.alpha = hidden ? 0.0 : 1.0

        if hidden {
            galleryExpandedConstraint.isActive = false
            galleryCollapsedConstraint.isActive = true
        } else {
            galleryCollapsedConstraint.isActive = false
            galleryExpandedConstraint.isActive = true
        }

    }
}
