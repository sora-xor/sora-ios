import UIKit

struct FinishedProjectLayoutMetadata: Withable, LayoutFlexible {
    var itemWidth: CGFloat = 335.0
    var minimumItemHeight: CGFloat = 357.0
    var minimumImageHeight: CGFloat = 137.0
    var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 16.0, left: 20.0, bottom: 20.0, right: 20.0)
    var cornerRadius: CGFloat = 10.0
    var detailsTopSpacing: CGFloat = 6.0
    var fundingProgressDetailsTopSpacing: CGFloat = 19.0
    var separatorTopSpacing: CGFloat = 15.0
    var separatorWidth: CGFloat = 1.0
    var actionsHeight: CGFloat = 16.0
    var favoriteIconWidth: CGFloat = 17.0
    var favoriteDetailsHorizontalSpacing: CGFloat = 7.0
    var votingIconWidth: CGFloat = 18.0
    var votingTitleTopSpacing: CGFloat = 15.0
    var votingIconHorizontalSpacing: CGFloat = 10.0
    var rewardDetailsTopSpacing: CGFloat = 15.0
    var rewardIconSize: CGSize = .zero
    var rewardHorizontalSpacing: CGFloat = 12.0

    var titleFont: UIFont = .projectCardTitle
    var detailsFont: UIFont = .projectCardDetails
    var fundingProgressDetailsFont: UIFont = .finishedProjectFundingProgressDetails
    var completionDetailsFont: UIFont = .finishedProjectCompletionDetails
    var votingTitleFont: UIFont = .finishedProjectVotingTitle
    var favoriteFont: UIFont = .projectCardFavorite
    var rewardFont: UIFont = .projectCardReward

    var minimumHorizontalSpacing: CGFloat = 4.0
    var multilineSpacing: CGFloat = 8.0
    var drawingOptions: NSStringDrawingOptions = .usesLineFragmentOrigin

    mutating func adjust(using adaptor: AdaptiveDesignable) {
        itemWidth *= adaptor.designScaleRatio.width
        minimumItemHeight *= adaptor.designScaleRatio.width
        minimumImageHeight *= adaptor.designScaleRatio.width

        if adaptor.isAdaptiveWidthDecreased {
            contentInsets.left *= adaptor.designScaleRatio.width
            contentInsets.right *= adaptor.designScaleRatio.width
            contentInsets.top *= adaptor.designScaleRatio.width
            contentInsets.bottom *= adaptor.designScaleRatio.width
            cornerRadius *= adaptor.designScaleRatio.width
            detailsTopSpacing *= adaptor.designScaleRatio.width
            fundingProgressDetailsTopSpacing *= adaptor.designScaleRatio.width
            separatorTopSpacing *= adaptor.designScaleRatio.width
            votingTitleTopSpacing *= adaptor.designScaleRatio.width
            rewardDetailsTopSpacing *= adaptor.designScaleRatio.width
            multilineSpacing *= adaptor.designScaleRatio.width
        }

    }
}

struct OpenProjectLayoutMetadata: Withable, LayoutFlexible {
    var itemWidth: CGFloat = 335.0
    var minimumItemHeight: CGFloat = 357.0
    var minimumImageHeight: CGFloat = 137.0
    var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 16.0, left: 20.0, bottom: 20.0, right: 20.0)
    var cornerRadius: CGFloat = 10.0

    var detailsTopSpacing: CGFloat = 6.0
    var fundingDetailsTopSpacing: CGFloat = 19.0
    var progressTopSpacing: CGFloat = 10.0
    var progressBarHeight: CGFloat = 4.0

    var actionsTopSpacing: CGFloat = 21.0
    var actionsHeight: CGFloat = 18.0
    var votingIconWidth: CGFloat = 19.0
    var votingIconHorizontalSpacing: CGFloat = 8.0
    var votedFriendsHorizontalSpacing: CGFloat = 8.0
    var favoriteIconSize: CGSize = CGSize(width: 17.0, height: 17.0)
    var favoriteHorizontalSpacing: CGFloat = 7.0

    var separatorTopSpacing: CGFloat = 17.0
    var separatorWidth: CGFloat = 1.0

    var rewardTopSpacing: CGFloat = 10.0
    var rewardIconSize: CGSize = .zero
    var rewardHorizontalSpacing: CGFloat = 12.0

    var titleFont: UIFont = .projectCardTitle
    var detailsFont: UIFont = .projectCardDetails
    var fundingDetailsFont: UIFont = .openedProjectProgressDetails
    var remainedTimeDetailsFont: UIFont = .openedProjectDeadline
    var votingStateFont: UIFont = .openedProjectVotingState
    var votedFriendsFont: UIFont = .openedProjectFriendsVoted
    var favoriteFont: UIFont = .projectCardFavorite
    var rewardFont: UIFont = .projectCardReward

    var minimumHorizontalSpacing: CGFloat = 4.0
    var multilineSpacing: CGFloat = 8.0
    var drawingOptions: NSStringDrawingOptions = .usesLineFragmentOrigin

    mutating func adjust(using adaptor: AdaptiveDesignable) {
        itemWidth *= adaptor.designScaleRatio.width
        minimumItemHeight *= adaptor.designScaleRatio.width
        minimumImageHeight *= adaptor.designScaleRatio.width

        if adaptor.isAdaptiveWidthDecreased {
            contentInsets.left *= adaptor.designScaleRatio.width
            contentInsets.right *= adaptor.designScaleRatio.width
            contentInsets.top *= adaptor.designScaleRatio.width
            contentInsets.bottom *= adaptor.designScaleRatio.width
            cornerRadius *= adaptor.designScaleRatio.width
            detailsTopSpacing *= adaptor.designScaleRatio.width
            fundingDetailsTopSpacing *= adaptor.designScaleRatio.width
            separatorTopSpacing *= adaptor.designScaleRatio.width
            actionsTopSpacing *= adaptor.designScaleRatio.width
            rewardTopSpacing *= adaptor.designScaleRatio.width
            multilineSpacing *= adaptor.designScaleRatio.width
        }

    }
}

struct ProjectLayoutMetadata {
    var openProjectLayoutMetadata: OpenProjectLayoutMetadata
    var finishedProjectLayoutMetadata: FinishedProjectLayoutMetadata

    init(openProjectLayoutMetadata: OpenProjectLayoutMetadata,
         finishedProjectLayoutMetadata: FinishedProjectLayoutMetadata) {
        self.openProjectLayoutMetadata = openProjectLayoutMetadata
        self.finishedProjectLayoutMetadata = finishedProjectLayoutMetadata
    }

    mutating func adjust(using adaptor: AdaptiveDesignable) {
        openProjectLayoutMetadata.adjust(using: adaptor)
        finishedProjectLayoutMetadata.adjust(using: adaptor)
    }
}

extension ProjectLayoutMetadata {
    static func createDefault() -> ProjectLayoutMetadata {
        let open = OpenProjectLayoutMetadata()
        let finished = FinishedProjectLayoutMetadata()

        return ProjectLayoutMetadata(openProjectLayoutMetadata: open,
                                     finishedProjectLayoutMetadata: finished)
    }
}
