/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

final class OpenProjectCollectionViewCell: AnimatableCollectionView {
    lazy var imageAppearanceAnimator: ViewAnimatorProtocol = TransitionAnimator(type: .fade)
    lazy var favoriteAnimator: ViewAnimatorProtocol = SpringAnimator()

    @IBOutlet private(set) var backgroundRoundedView: RoundedView!
    @IBOutlet private(set) var imageView: UIImageView!
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var descriptionLabel: UILabel!
    @IBOutlet private(set) var fundingProgressView: ProgressView!
    @IBOutlet private(set) var fundingProgressLabel: UILabel!
    @IBOutlet private(set) var fundingDurationLabel: UILabel!
    @IBOutlet private(set) var newIndicatorView: RoundedButton!
    @IBOutlet private(set) var voteButton: RoundedButton!
    @IBOutlet private(set) var friendsDetailsLabel: UILabel!
    @IBOutlet private(set) var favoriteButton: RoundedButton!
    @IBOutlet private(set) var favoriteDetailsLabel: UILabel!
    @IBOutlet private(set) var footerView: BorderedContainerView!
    @IBOutlet private(set) var rewardIconView: UIImageView!
    @IBOutlet private(set) var rewardLabel: UILabel!

    private var viewModel: OpenProjectViewModelProtocol?
    private var layoutMetadata: OpenProjectLayoutMetadata?

    // MARK: Internal Management

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.imageViewModel?.cancel()
        imageView.image = nil
    }

    // MARK: View Model Setup

    func bind(viewModel: OpenProjectViewModelProtocol,
              layoutMetadata: OpenProjectLayoutMetadata) {
        self.viewModel = viewModel
        self.layoutMetadata = layoutMetadata

        backgroundRoundedView.cornerRadius = layoutMetadata.cornerRadius

        titleLabel.text = viewModel.content.title
        descriptionLabel.text = viewModel.content.details
        fundingProgressView.setProgress(CGFloat(viewModel.content.fundingProgressValue), animated: false)
        fundingProgressLabel.text = viewModel.content.fundingProgressDetails
        fundingDurationLabel.text = viewModel.content.remainedTimeDetails
        friendsDetailsLabel.text = viewModel.content.votedFriendsDetails
        rewardLabel.text = viewModel.content.rewardDetails

        newIndicatorView.alpha = viewModel.content.isNew ? 1.0 : 0.0
        footerView.alpha = viewModel.content.hasRewardDetails ? 1.0 : 0.0

        updateVoteButton()
        updateFavoriteButton()

        updateImage()

        setNeedsLayout()
    }

    private func updateImage() {
        if let image = viewModel?.imageViewModel?.image {
            imageView.image = image
            return
        }

        viewModel?.imageViewModel?.loadImage { [weak self] (image, error) in
            guard error == nil else {
                return
            }

            guard let strongSelf = self else {
                return
            }

            strongSelf.imageView.image = image
            strongSelf.imageAppearanceAnimator.animate(view: strongSelf.imageView,
                                                       completionBlock: nil)
        }
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        guard
            let layout = viewModel?.layout,
            let content = viewModel?.content,
            let metadata = layoutMetadata else {
            return
        }

        var origin = CGPoint(x: 0.0, y: 0.0)

        layoutImage(at: &origin,
                    layout: layout,
                    metadata: metadata)

        if content.isNew {
            layoutNewIndicator(at: &origin,
                               layout: layout,
                               metadata: metadata)
        }

        origin.x = metadata.contentInsets.left
        origin.y += metadata.contentInsets.top

        layoutText(at: &origin,
                   layout: layout,
                   metadata: metadata)

        layoutFundingProgress(at: &origin,
                              layout: layout,
                              metadata: metadata)

        layoutVoteAction(at: &origin,
                         layout: layout,
                         metadata: metadata)

        layoutFriendDetails(at: &origin,
                            layout: layout,
                            metadata: metadata)

        layoutFavorite(at: &origin,
                       layout: layout,
                       metadata: metadata)

        if content.hasRewardDetails {
            layoutReward(at: &origin,
                         layout: layout,
                         metadata: metadata)
        }
    }

    // MARK: Actions

    @IBAction private func actionVote(sender: AnyObject) {
        guard let model = viewModel else {
            return
        }

        _ = viewModel?.delegate?.vote(model: model)
    }

    @IBAction private func actionToggleFavorite(sender: AnyObject) {
        guard let model = viewModel else {
            return
        }

        if viewModel?.delegate?.toggleFavorite(model: model) == true {
            updateFavoriteButton()
            favoriteAnimator.animate(view: favoriteButton,
                                     completionBlock: nil)
        }
    }

    private func updateVoteButton() {
        guard let viewModel = viewModel else {
            return
        }

        voteButton.imageWithTitleView?.title = viewModel.content.voteTitle
        voteButton.imageWithTitleView?.iconImage = viewModel.content.isVoted ? R.image.voteButtonIconSel()
            : R.image.voteButtonIcon()
        voteButton.invalidateLayout()
    }

    private func updateFavoriteButton() {
        guard let viewModel = viewModel else {
            return
        }

        favoriteButton.imageWithTitleView?.iconImage = viewModel.content.isFavorite ? R.image.favoriteButtonIconSel()
            : R.image.favoriteButtonIcon()
        favoriteDetailsLabel.text = viewModel.content.favoriteDetails
    }
}

extension OpenProjectCollectionViewCell {
    private func layoutImage(at origin: inout CGPoint,
                             layout: OpenProjectLayout,
                             metadata: OpenProjectLayoutMetadata) {
        imageView.frame = CGRect(origin: origin,
                                 size: layout.imageSize)
        origin.y += layout.imageSize.height
    }

    private func layoutNewIndicator(at origin: inout CGPoint,
                                    layout: OpenProjectLayout,
                                    metadata: OpenProjectLayoutMetadata) {
        let originX = layout.itemSize.width - metadata.contentInsets.right - newIndicatorView.frame.size.width
        let originY = layout.imageSize.height - newIndicatorView.frame.size.height / 2.0
        newIndicatorView.frame = CGRect(x: originX,
                                        y: originY,
                                        width: newIndicatorView.frame.size.width,
                                        height: newIndicatorView.frame.size.height)
    }

    private func layoutText(at origin: inout CGPoint,
                            layout: OpenProjectLayout,
                            metadata: OpenProjectLayoutMetadata) {

        titleLabel.frame = CGRect(x: origin.x,
                                  y: origin.y,
                                  width: layout.titleSize.width,
                                  height: layout.titleSize.height)

        origin.y += layout.titleSize.height

        origin.y += metadata.detailsTopSpacing

        descriptionLabel.frame = CGRect(x: origin.x,
                                        y: origin.y,
                                        width: layout.detailsSize.width,
                                        height: layout.detailsSize.height)

        origin.y += layout.detailsSize.height
    }

    private func layoutFundingProgress(at origin: inout CGPoint,
                                       layout: OpenProjectLayout,
                                       metadata: OpenProjectLayoutMetadata) {
        origin.y += metadata.fundingDetailsTopSpacing

        var fundingDetailsWidth = layout.fundingProgressDetailsSize.width
        fundingDetailsWidth += metadata.minimumHorizontalSpacing
        fundingDetailsWidth += layout.remainedTimeDetailsSize.width

        if fundingDetailsWidth <= metadata.drawingBoundingSize.width {
            let height = max(layout.fundingProgressDetailsSize.height,
                             layout.remainedTimeDetailsSize.height)

            let fundingOriginY = origin.y + height / 2.0
                - layout.fundingProgressDetailsSize.height / 2.0

            fundingProgressLabel.frame = CGRect(x: origin.x,
                                                y: fundingOriginY,
                                                width: layout.fundingProgressDetailsSize.width,
                                                height: layout.fundingProgressDetailsSize.height)

            let remainedTimeOriginY = origin.y + height / 2.0
                - layout.remainedTimeDetailsSize.height / 2.0
            let remainedTimeOriginX = origin.x + metadata.drawingBoundingSize.width
                - layout.remainedTimeDetailsSize.width

            fundingDurationLabel.frame = CGRect(x: remainedTimeOriginX,
                                                y: remainedTimeOriginY,
                                                width: layout.remainedTimeDetailsSize.width,
                                                height: layout.remainedTimeDetailsSize.height)

            origin.y += height
        } else {
            fundingProgressLabel.frame = CGRect(x: origin.x,
                                                y: origin.y,
                                                width: layout.fundingProgressDetailsSize.width,
                                                height: layout.fundingProgressDetailsSize.height)
            origin.y += layout.fundingProgressDetailsSize.height
            origin.y += metadata.multilineSpacing

            fundingDurationLabel.frame = CGRect(x: origin.x,
                                                y: origin.y,
                                                width: layout.remainedTimeDetailsSize.width,
                                                height: layout.remainedTimeDetailsSize.height)

            origin.y += layout.remainedTimeDetailsSize.height
        }

        origin.y += metadata.progressTopSpacing

        fundingProgressView.frame = CGRect(x: origin.x,
                                           y: origin.y,
                                           width: metadata.drawingBoundingSize.width,
                                           height: metadata.progressBarHeight)

        origin.y += metadata.progressBarHeight
    }

    private func layoutVoteAction(at origin: inout CGPoint,
                                  layout: OpenProjectLayout,
                                  metadata: OpenProjectLayoutMetadata) {
        origin.y += metadata.actionsTopSpacing

        let votingStateWidth = metadata.votingIconWidth + metadata.votingIconHorizontalSpacing
            + layout.voteTitleSize.width

        voteButton.frame = CGRect(x: origin.x,
                                  y: origin.y + metadata.actionsHeight / 2.0 - voteButton.frame.size.height / 2.0,
                                  width: votingStateWidth,
                                  height: voteButton.frame.size.height)

        origin.x += votingStateWidth
    }

    private func layoutFriendDetails(at origin: inout CGPoint,
                                     layout: OpenProjectLayout,
                                     metadata: OpenProjectLayoutMetadata) {

        let offsetY = metadata.actionsHeight / 2.0 - layout.votedFriendsDetailsSize.height / 2.0

        if origin.x + metadata.votedFriendsHorizontalSpacing + layout.votedFriendsDetailsSize.width
            <= metadata.contentInsets.left + metadata.drawingBoundingSize.width {

            friendsDetailsLabel.frame = CGRect(x: origin.x + metadata.votedFriendsHorizontalSpacing,
                                               y: origin.y + offsetY,
                                               width: layout.votedFriendsDetailsSize.width,
                                               height: layout.votedFriendsDetailsSize.height)

            origin.x += metadata.votedFriendsHorizontalSpacing + layout.votedFriendsDetailsSize.width
        } else {
            origin.x = metadata.contentInsets.left
            origin.y += metadata.actionsHeight + metadata.multilineSpacing

            friendsDetailsLabel.frame = CGRect(x: origin.x,
                                               y: origin.y + offsetY,
                                               width: layout.votedFriendsDetailsSize.width,
                                               height: layout.votedFriendsDetailsSize.height)

            origin.x += layout.votedFriendsDetailsSize.width
        }
    }

    private func layoutFavorite(at origin: inout CGPoint,
                                layout: OpenProjectLayout,
                                metadata: OpenProjectLayoutMetadata) {
        let favoriteWidth = layout.favoriteDetailsSize.width + metadata.favoriteHorizontalSpacing
            + metadata.favoriteIconSize.width

        if origin.x + metadata.minimumHorizontalSpacing + favoriteWidth
            > metadata.contentInsets.left + metadata.drawingBoundingSize.width {
            origin.y += metadata.multilineSpacing + metadata.actionsHeight
        }

        var offsetX = metadata.contentInsets.left + metadata.drawingBoundingSize.width - favoriteButton.frame.size.width
        offsetX += (favoriteButton.frame.width - metadata.favoriteIconSize.width) / 2.0
        var offsetY = metadata.actionsHeight / 2.0 - favoriteButton.frame.size.height / 2.0
        favoriteButton.frame = CGRect(x: offsetX,
                                      y: origin.y + offsetY,
                                      width: favoriteButton.frame.size.width,
                                      height: favoriteButton.frame.size.height)

        offsetX -= metadata.favoriteHorizontalSpacing + layout.favoriteDetailsSize.width
        offsetX += (favoriteButton.frame.width - metadata.favoriteIconSize.width) / 2.0
        offsetY = metadata.actionsHeight / 2.0 - layout.favoriteDetailsSize.height / 2.0

        favoriteDetailsLabel.frame = CGRect(x: offsetX,
                                            y: origin.y + offsetY,
                                            width: layout.favoriteDetailsSize.width,
                                            height: layout.favoriteDetailsSize.height)

        origin.y += metadata.actionsHeight
    }

    private func layoutReward(at origin: inout CGPoint,
                              layout: OpenProjectLayout,
                              metadata: OpenProjectLayoutMetadata) {
        origin.y += metadata.separatorTopSpacing

        let height = metadata.separatorWidth + metadata.rewardTopSpacing
            + layout.rewardDetailsSize.height + metadata.contentInsets.bottom

        footerView.frame = CGRect(x: 0.0,
                                  y: origin.y,
                                  width: bounds.width,
                                  height: height)

        if metadata.rewardIconSize != .zero {
            rewardIconView.frame = CGRect(x: metadata.contentInsets.left,
                                          y: footerView.bounds.midY - metadata.rewardIconSize.height / 2.0,
                                          width: metadata.rewardIconSize.width,
                                          height: metadata.rewardIconSize.height)

            rewardLabel.frame = CGRect(x: rewardIconView.frame.maxX + metadata.rewardHorizontalSpacing,
                                       y: footerView.bounds.midY - layout.rewardDetailsSize.height / 2.0,
                                       width: layout.rewardDetailsSize.width,
                                       height: layout.rewardDetailsSize.height)
        } else {
            rewardLabel.frame = CGRect(x: metadata.contentInsets.left,
                                       y: footerView.bounds.midY - layout.rewardDetailsSize.height / 2.0,
                                       width: layout.rewardDetailsSize.width,
                                       height: layout.rewardDetailsSize.height)
        }

        origin.y += footerView.frame.size.height
    }
}
