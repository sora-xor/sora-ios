import UIKit
import SoraUI
import SoraFoundation

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

            if self.applyDiscussionChanges(since: oldViewModel) {
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
                progressLabelTrallingWhenLong.isActive = false
                deadlineLabelTopWhenLong.isActive = false
                deadlineLabelLeftWhenLong.isActive = false
                progressLabelTrallingWhenShort.isActive = true
                deadlineLabelTopWhenShort.isActive = true
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
                statisticsTopWithFavorite.isActive = false
                statisticsTopWithReward.isActive = true
            } else {
                statisticsTopWithReward.isActive = false
                statisticsTopWithFavorite.isActive = true
            }

            hasLayoutChanges = true
        }

        return hasLayoutChanges
    }

    private func applyDiscussionChanges(since oldViewModel: ProjectDetailsViewModelProtocol?) -> Bool {
        guard let viewModel = viewModel else {
            return false
        }

        var hasLayoutChanges = false

        if oldViewModel == nil || (oldViewModel?.discussionDetails != viewModel.discussionDetails) {
            if let discussionDetails = viewModel.discussionDetails {
                discussionContentView.alpha = 1.0
                discussionLinkView.imageWithTitleView?.title = discussionDetails
                discussionLinkView.invalidateLayout()
            } else {
                discussionContentView.alpha = 0.0
            }

            hasLayoutChanges = true
        }

        let shouldChangeLayout = (oldViewModel == nil) ||
            ((oldViewModel?.rewardDetails == nil) != (viewModel.rewardDetails == nil)) ||
            ((oldViewModel?.statisticsDetails == nil) != (viewModel.statisticsDetails == nil))

        if shouldChangeLayout {
            if viewModel.statisticsDetails != nil {
                discussionTopWithFavorite.isActive = false
                discussionTopWithReward.isActive = false
                discussionTopWithStatistics.isActive = true
            } else if viewModel.rewardDetails != nil {
                discussionTopWithFavorite.isActive = false
                discussionTopWithStatistics.isActive = false
                discussionTopWithReward.isActive = true
            } else {
                discussionTopWithReward.isActive = false
                discussionTopWithStatistics.isActive = false
                discussionTopWithFavorite.isActive = true
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
            updateDetails()
            detailsTextViewHeight.constant = detailsHeight

            hasLayoutChanges = true
        }

        let shouldChangeLayout = (oldViewModel == nil) ||
            ((oldViewModel?.rewardDetails == nil) != (viewModel.rewardDetails == nil)) ||
            ((oldViewModel?.statisticsDetails == nil) != (viewModel.statisticsDetails == nil)) ||
            ((oldViewModel?.discussionDetails == nil) != (viewModel.discussionDetails == nil))

        if shouldChangeLayout {
            if viewModel.discussionDetails != nil {
                detailsTopWithReward.isActive = false
                detailsTopWithFavorite.isActive = false
                detailsTopWithStatistics.isActive = false
                detailsTopWithDiscussion.isActive = true
            } else if viewModel.statisticsDetails != nil {
                detailsTopWithReward.isActive = false
                detailsTopWithFavorite.isActive = false
                detailsTopWithDiscussion.isActive = false
                detailsTopWithStatistics.isActive = true
            } else if viewModel.rewardDetails != nil {
                detailsTopWithStatistics.isActive = false
                detailsTopWithFavorite.isActive = false
                detailsTopWithDiscussion.isActive = false
                detailsTopWithReward.isActive = true
            } else {
                detailsTopWithStatistics.isActive = false
                detailsTopWithReward.isActive = false
                detailsTopWithDiscussion.isActive = false
                detailsTopWithFavorite.isActive = true
            }
        }

        statisticsView.borderType = viewModel.rewardDetails != nil ? .top : .none

        return hasLayoutChanges
    }

    private func applyGallerySectionChanges(since oldViewModel: ProjectDetailsViewModelProtocol?) -> Bool {
        guard viewModel?.galleryImageViewModels != oldViewModel?.galleryImageViewModels else {
            return false
        }

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
        let languages = localizationManager?.preferredLocalizations

        if value {
            favoriteButton.imageWithTitleView?.title = R.string.localizable
                .projectRemoveFromFavourite(preferredLanguages: languages)
            favoriteButton.imageWithTitleView?.iconImage = R.image.favoriteButtonIconSel()
        } else {
            favoriteButton.imageWithTitleView?.title = R.string.localizable
                .projectAddToFavourite(preferredLanguages: languages)
            favoriteButton.imageWithTitleView?.iconImage = R.image.favoriteButtonIcon()
        }

        favoriteButton.invalidateLayout()
    }

    private func setProgressView(hidden: Bool) {
        progressView.alpha = hidden ? 0.0 : 1.0

        if hidden {
            voteButtonTopWhenOpen.isActive = false
            voteButtonTopWhenFinished.isActive = true
        } else {
            voteButtonTopWhenFinished.isActive = false
            voteButtonTopWhenOpen.isActive = true
        }
    }

    private func updateDetails() {
        detailsTextView.expanded = true
        detailsTextView.text = viewModel?.details
        detailsTextView.showsFooter = false
    }

    private func updateActionsLayout(from previousActionWidth: CGFloat) -> Bool {
        var hasLayoutChanges = false

        let actionsWidth = voteButton.intrinsicContentSize.width + Constants.horizontalMinimumSpacing
            + favoriteButton.intrinsicContentSize.width

        let shouldChangeLayout = (previousActionWidth <= contentWidth) != (actionsWidth <= contentWidth)

        if shouldChangeLayout {
            if actionsWidth <= contentWidth {
                voteButtonCenterWhenLong.isActive = false
                favoriteButtonTopWhenLong.isActive = false
                favoriteButtonCenterXWhenLong.isActive = false
                voteButtonLeftWhenShort.isActive = true
                favoriteButtonCenterYWhenShort.isActive = true
                favoriteButtonTrallingWhenShort.isActive = true
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
            detailsHeight = Constants.detailsMinimumHeight
            return
        }

        let boundingSize = CGSize(width: detailsTextView.frame.size.width, height: CGFloat.greatestFiniteMagnitude)
        detailsHeight = (text as NSString).boundingRect(with: boundingSize,
                                                        options: .usesLineFragmentOrigin,
                                                        attributes: [.font: detailsTextView.textFont],
                                                        context: nil).size.height
        detailsHeight += Constants.detailsBottomSpacing

        detailsHeight = max(detailsHeight, Constants.detailsMinimumHeight)
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
