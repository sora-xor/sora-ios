import UIKit

struct ReferendumLayoutMetadata: Withable, LayoutFlexible {
    var itemWidth: CGFloat = 335.0
    var minimumItemHeight: CGFloat = 357.0
    var minimumImageHeight: CGFloat = 137.0
    var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 16.0, left: 20.0, bottom: 20.0, right: 20.0)
    var cornerRadius: CGFloat = 10.0

    var remainedTopSpacing: CGFloat = 16.0
    var remainedHorizontalSpacing: CGFloat = 4.0
    var remainedHeight: CGFloat = 20.0
    var titleTopSpacing: CGFloat = 8.0
    var detailsTopSpacing: CGFloat = 8.0
    var bottomBarTopSpacing: CGFloat = 9.0
    var bottomSeparatorHeight: CGFloat = 1.0
    var votingTitleTopSpacing: CGFloat = 8.0
    var votingTitleHeight: CGFloat = 21.0
    var progressBarTopSpacing: CGFloat = 2.0
    var progressBarHeight: CGFloat = 4.0
    var votingDetailsTopSpacing: CGFloat = 8.0
    var votingDetailsHorizontalSpacing: CGFloat = 5.0
    var votingIndicatorSize: CGSize = CGSize(width: 20.0, height: 20.0)
    var touchAreaInset: CGFloat = 4.0

    var titleFont: UIFont = .referendumTitle
    var detailsFont: UIFont = .referendumDetails

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
            remainedTopSpacing *= adaptor.designScaleRatio.width
            detailsTopSpacing *= adaptor.designScaleRatio.width
            votingTitleTopSpacing *= adaptor.designScaleRatio.width
            progressBarTopSpacing *= adaptor.designScaleRatio.width
            votingDetailsTopSpacing *= adaptor.designScaleRatio.width
        }
    }
}
