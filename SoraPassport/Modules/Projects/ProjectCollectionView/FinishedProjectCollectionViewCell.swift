import UIKit
import SoraUI

final class FinishedProjectCollectionViewCell: AnimatableCollectionView {
    lazy var imageAppearanceAnimator: ViewAnimatorProtocol = TransitionAnimator(type: .fade)
    lazy var favoriteAnimator: ViewAnimatorProtocol = SpringAnimator()

    private(set) var viewModel: FinishedProjectViewModelProtocol?
    private(set) var layoutMetadata: FinishedProjectLayoutMetadata?

    @IBOutlet private(set) var backgroundRoundedView: RoundedView!
    @IBOutlet private(set) var imageView: UIImageView!
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var descriptionLabel: UILabel!
    @IBOutlet private(set) var fundingProgressLabel: UILabel!
    @IBOutlet private(set) var fundingDurationLabel: UILabel!
    @IBOutlet private(set) var voteView: ImageWithTitleView!
    @IBOutlet private(set) var favoriteButton: RoundedButton!
    @IBOutlet private(set) var favoriteDetailsLabel: UILabel!
    @IBOutlet private(set) var footerView: BorderedContainerView!
    @IBOutlet private(set) var rewardIconView: UIImageView!
    @IBOutlet private(set) var rewardLabel: UILabel!

    // MARK: Internal Management

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.imageViewModel?.cancel()
        imageView.image = nil
    }

    // MARK: View Model Setup

    func bind(viewModel: FinishedProjectViewModelProtocol,
              layoutMetadata: FinishedProjectLayoutMetadata) {
        self.viewModel = viewModel
        self.layoutMetadata = layoutMetadata

        backgroundRoundedView.cornerRadius = layoutMetadata.cornerRadius

        titleLabel.text = viewModel.content.title
        descriptionLabel.text = viewModel.content.details
        fundingProgressLabel.text = viewModel.content.fundingProgressDetails
        fundingDurationLabel.text = viewModel.content.completionTimeDetails

        updateVotingAndReward()
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

    private func updateFavoriteButton() {
        guard let viewModel = viewModel else {
            return
        }

        favoriteButton.imageWithTitleView?.iconImage = viewModel.content.isFavorite ? R.image.favoriteButtonIconSel()
            : R.image.favoriteButtonIcon()
        favoriteDetailsLabel.text = viewModel.content.favoriteDetails
    }

    private func updateVotingAndReward() {
        guard let viewModel = viewModel, let metadata = layoutMetadata else {
            return
        }

        rewardIconView.alpha = metadata.rewardIconSize != .zero ? 1.0 : 0.0
        rewardLabel.alpha = viewModel.content.hasRewardDetails ? 1.0 : 0.0

        voteView.iconImage = viewModel.content.isSuccessfull ? R.image.successfullVotingIcon()
            : R.image.unsuccessfulVotingIcon()
        voteView.title = viewModel.content.votingTitle
        rewardLabel.text = viewModel.content.rewardDetails
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

        origin.x = metadata.contentInsets.left
        origin.y += metadata.contentInsets.top

        layoutText(at: &origin,
                   layout: layout,
                   metadata: metadata)

        layoutFundingProgress(at: &origin,
                              layout: layout,
                              metadata: metadata)

        let hasRewardIcon = metadata.rewardIconSize != .zero

        layoutFooter(at: &origin,
                     layout: layout,
                     metadata: metadata,
                     shouldLayoutReward: content.isVoted,
                     hasRewardIcon: hasRewardIcon)
    }

    // MARK: Actions

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
}

extension FinishedProjectCollectionViewCell {
    private func layoutImage(at origin: inout CGPoint,
                             layout: FinishedProjectLayout,
                             metadata: FinishedProjectLayoutMetadata) {
        imageView.frame = CGRect(origin: origin,
                                 size: layout.imageSize)
        origin.y += layout.imageSize.height
    }

    private func layoutText(at origin: inout CGPoint,
                            layout: FinishedProjectLayout,
                            metadata: FinishedProjectLayoutMetadata) {

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
                                       layout: FinishedProjectLayout,
                                       metadata: FinishedProjectLayoutMetadata) {
        origin.y += metadata.fundingProgressDetailsTopSpacing

        var fundingDetailsWidth = layout.fundingProgressDetailsSize.width
        fundingDetailsWidth += metadata.minimumHorizontalSpacing
        fundingDetailsWidth += layout.completionTimeDetailsSize.width

        if fundingDetailsWidth <= metadata.drawingBoundingSize.width {
            let height = max(layout.fundingProgressDetailsSize.height,
                             layout.completionTimeDetailsSize.height)

            let fundingOriginY = origin.y + height / 2.0
                - layout.fundingProgressDetailsSize.height / 2.0

            fundingProgressLabel.frame = CGRect(x: origin.x,
                                                y: fundingOriginY,
                                                width: layout.fundingProgressDetailsSize.width,
                                                height: layout.fundingProgressDetailsSize.height)

            let remainedTimeOriginX = origin.x + metadata.drawingBoundingSize.width
                - layout.completionTimeDetailsSize.width
            let remainedTimeOriginY = origin.y + height / 2.0
                - layout.completionTimeDetailsSize.height / 2.0

            fundingDurationLabel.frame = CGRect(x: remainedTimeOriginX,
                                                y: remainedTimeOriginY,
                                                width: layout.completionTimeDetailsSize.width,
                                                height: layout.completionTimeDetailsSize.height)

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
                                                width: layout.completionTimeDetailsSize.width,
                                                height: layout.completionTimeDetailsSize.height)

            origin.y += layout.completionTimeDetailsSize.height
        }
    }

    private func layoutFooter(at origin: inout CGPoint,
                              layout: FinishedProjectLayout,
                              metadata: FinishedProjectLayoutMetadata,
                              shouldLayoutReward: Bool,
                              hasRewardIcon: Bool) {
        origin.y += metadata.separatorTopSpacing

        var footerOrigin = CGPoint(x: metadata.contentInsets.left, y: metadata.separatorWidth)

        layoutVote(at: &footerOrigin,
                   layout: layout,
                   metadata: metadata)

        layoutFavorite(at: &footerOrigin,
                       layout: layout,
                       metadata: metadata)

        if shouldLayoutReward {
            layoutReward(at: &footerOrigin,
                         layout: layout,
                         metadata: metadata,
                         hasIcon: hasRewardIcon)
        }

        footerView.frame = CGRect(x: 0.0,
                                  y: origin.y,
                                  width: bounds.size.width,
                                  height: footerOrigin.y)

        origin.y += footerOrigin.y
    }

    private func layoutVote(at origin: inout CGPoint,
                            layout: FinishedProjectLayout,
                            metadata: FinishedProjectLayoutMetadata) {
        origin.y += metadata.votingTitleTopSpacing

        let voteWidth = metadata.votingIconWidth + metadata.votingIconHorizontalSpacing + layout.votingTitleSize.width
        voteView.frame = CGRect(x: origin.x,
                                y: origin.y + metadata.actionsHeight / 2.0 - voteView.frame.size.height / 2.0,
                                width: voteWidth,
                                height: voteView.frame.size.height)

        origin.x += voteWidth
    }

    private func layoutFavorite(at origin: inout CGPoint,
                                layout: FinishedProjectLayout,
                                metadata: FinishedProjectLayoutMetadata) {
        let favoriteWidth = metadata.favoriteIconWidth + metadata.favoriteDetailsHorizontalSpacing
            + layout.favoriteDetailsSize.width

        if origin.x + favoriteWidth > metadata.drawingBoundingSize.width + metadata.contentInsets.left {
            origin.y += metadata.actionsHeight + metadata.multilineSpacing
        }

        var offsetX = metadata.contentInsets.left + metadata.drawingBoundingSize.width
            - favoriteButton.frame.size.width
        offsetX += (favoriteButton.frame.size.width - metadata.favoriteIconWidth) / 2.0

        var offsetY = origin.y + metadata.actionsHeight / 2.0 - favoriteButton.frame.size.height / 2.0
        favoriteButton.frame = CGRect(x: offsetX,
                                      y: offsetY,
                                      width: favoriteButton.frame.size.width,
                                      height: favoriteButton.frame.size.height)

        offsetX -= metadata.favoriteDetailsHorizontalSpacing + layout.favoriteDetailsSize.width
        offsetX += (favoriteButton.frame.size.width - metadata.favoriteIconWidth) / 2.0

        offsetY = origin.y + metadata.actionsHeight / 2.0 - layout.favoriteDetailsSize.height / 2.0
        favoriteDetailsLabel.frame = CGRect(x: offsetX,
                                            y: offsetY,
                                            width: layout.favoriteDetailsSize.width,
                                            height: layout.favoriteDetailsSize.height)

        origin.x = metadata.contentInsets.left
        origin.y += metadata.actionsHeight
    }

    private func layoutReward(at origin: inout CGPoint,
                              layout: FinishedProjectLayout,
                              metadata: FinishedProjectLayoutMetadata,
                              hasIcon: Bool) {
        origin.y += metadata.rewardDetailsTopSpacing

        let centerY = origin.y + layout.rewardDetailsSize.height / 2.0

        if hasIcon {
            rewardIconView.frame = CGRect(x: origin.x,
                                          y: centerY - rewardIconView.frame.size.height / 2.0,
                                          width: rewardIconView.frame.size.width,
                                          height: rewardIconView.frame.size.height)
            rewardLabel.frame = CGRect(x: rewardIconView.frame.maxX + metadata.rewardHorizontalSpacing,
                                       y: centerY - layout.rewardDetailsSize.height / 2.0,
                                       width: layout.rewardDetailsSize.width,
                                       height: layout.rewardDetailsSize.height)
        } else {
            rewardLabel.frame = CGRect(x: origin.x,
                                       y: centerY - layout.rewardDetailsSize.height / 2.0,
                                       width: layout.rewardDetailsSize.width,
                                       height: layout.rewardDetailsSize.height)
        }

        origin.y += layout.rewardDetailsSize.height
    }
}
