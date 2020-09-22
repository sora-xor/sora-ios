import UIKit
import SoraUI

final class ActivityFeedSkeletonViewCell: SkeletonCollectionViewCell {
    private struct Constants {
        static let contentInsets = UIEdgeInsets(top: 0.0, left: 15.0, bottom: 20.0, right: 15.0)
        static let itemHeight: CGFloat = 212.0

        static let decoratorTopMargin: CGFloat = 50.0

        static let decoratorShadowInset: UIEdgeInsets = UIEdgeInsets(top: 0.0,
                                                                     left: 5.0,
                                                                     bottom: 5.0,
                                                                     right: 5.0)

        static let decoratorInternalInsets: UIEdgeInsets = UIEdgeInsets(top: 70.0,
                                                                        left: 25.0,
                                                                        bottom: 25.0,
                                                                        right: 25.0)

        static let decoratorCornerRadius: CGFloat = 10.0
        static let decoratorBackgroundColor: UIColor = UIColor.white
        static let decoratorShadowColor: UIColor = UIColor(red: 115.0 / 255.0,
                                                      green: 168.0 / 255.0,
                                                      blue: 168.0 / 255.0,
                                                      alpha: 0.42)
        static let decoratorShadowOffset: CGSize = CGSize(width: 0.0, height: 1.0)
        static let decoratorShadowRadius: CGFloat = 2.0

        static let sectionSize: CGSize = CGSize(width: 80.0, height: 16.0)

        static let sectionFillStartColor = UIColor(red: 206.0 / 255.0,
                                                   green: 225.0 / 255.0,
                                                   blue: 225.0 / 255.0,
                                                   alpha: 1.0)

        static let sectionFillEndColor = UIColor(red: 206.0 / 255.0,
                                                 green: 225.0 / 255.0,
                                                 blue: 225.0 / 255.0,
                                                 alpha: 0.8)

        static let itemFillStartColor: UIColor = UIColor(white: 230.0 / 255.0, alpha: 1.0)
        static let itemFillEndColor: UIColor = UIColor(white: 230.0 / 255.0, alpha: 0.8)

        static let iconSize: CGFloat = 16.0

        static let nameSize: CGSize = CGSize(width: 85.0, height: 16.0)
        static let iconNameSpacing: CGFloat = 10.0

        static let timestampSize: CGSize = CGSize(width: 36.0, height: 16)

        static let titleSize: CGSize = CGSize(width: 159.0, height: 16.0)
        static let titleNameSpacing: CGFloat = 15.0

        static let detailsTitleSpacing: CGFloat = 8.0
        static let detailsLineHeight: CGFloat = 14.0
        static let detailsLineSpacing: CGFloat = 4.0
        static let detailsHeight: CGFloat = 50.0
        static let detailsLineCount: Int = 3
        static let detailsLastLineFraction: CGFloat = 0.3
    }

    override func configureSkeleton(for viewModel: SkeletonCellViewModel) -> SkrullableView? {
        var itemsCount = UInt32(viewModel.contentSize.height / Constants.itemHeight)

        if UInt32(viewModel.contentSize.height) % UInt32(Constants.itemHeight) != 0 {
            itemsCount += 1
        }

        let width = viewModel.contentSize.width - Constants.contentInsets.left - Constants.contentInsets.right
        let height = Constants.itemHeight + Constants.decoratorShadowInset.bottom

        let itemSize = CGSize(width: width, height: height)

        let skrull = Skrull(size: itemSize,
                            decorations: [
                                createBackgroundDecorator(for: itemSize)
            ],
                            skeletons: [
                                createSectionSkeleton(for: itemSize),
                                createIconSkeleton(for: itemSize),
                                createNameSkeleton(for: itemSize),
                                createTimestampSkeleton(for: itemSize),
                                createTitleSkeleton(for: itemSize),
                                createTextSkeleton(for: itemSize)

            ])
            .fillSkeletonStart(Constants.itemFillStartColor)
            .fillSkeletonEnd(color: Constants.itemFillEndColor)
            .insets(Constants.contentInsets)
            .replicateVertically(count: itemsCount, spacing: 0.0)

        let view = skrull.build()

        return view
    }

    private func createSectionSkeleton(for itemSize: CGSize) -> Skeletonable {
        let originalX = itemSize.skrullMapX(Constants.decoratorShadowInset.left + Constants.sectionSize.width / 2.0)
        let originalY = itemSize.skrullMapY(Constants.decoratorTopMargin / 2.0)

        let cornerRadii = CGSize(width: Constants.sectionSize.skrullMapX(Constants.sectionSize.height / 2.0),
                                 height: Constants.sectionSize.skrullMapY(Constants.sectionSize.height / 2.0))

        let size = CGSize(width: itemSize.skrullMapX(Constants.sectionSize.width),
                          height: itemSize.skrullMapY(Constants.sectionSize.height))

        return SingleSkeleton(position: CGPoint(x: originalX, y: originalY), size: size)
            .round(cornerRadii, mode: .allCorners)
            .fillStart(Constants.sectionFillStartColor)
            .fillEnd(Constants.sectionFillEndColor)
    }

    private func createBackgroundDecorator(for itemSize: CGSize) -> Decorable {
        let originalWidth = itemSize.width -
            (Constants.decoratorShadowInset.left + Constants.decoratorShadowInset.right)
        let originalHeight = itemSize.height - (Constants.decoratorTopMargin + Constants.decoratorShadowInset.bottom)

        let originalY = itemSize.height - (itemSize.height - Constants.decoratorTopMargin) / 2.0

        let size = CGSize(width: itemSize.skrullMapX(originalWidth),
                          height: itemSize.skrullMapY(originalHeight))

        let position = CGPoint(x: CGPoint.skrullCenter.x,
                               y: itemSize.skrullMapY(originalY))

        let cornerRadii = CGSize(width: Constants.decoratorCornerRadius / originalWidth,
                                 height: Constants.decoratorCornerRadius / originalHeight)

        return SingleDecoration(position: position, size: size)
            .round(cornerRadii, mode: .allCorners)
            .fill(Constants.decoratorBackgroundColor)
            .shadow(Constants.decoratorShadowColor,
                    offset: Constants.decoratorShadowOffset,
                    radius: Constants.decoratorShadowRadius)
    }

    private func createIconSkeleton(for itemSize: CGSize) -> Skeletonable {
        let originalPosition = CGPoint(x: Constants.decoratorInternalInsets.left + Constants.iconSize / 2.0,
                                       y: Constants.decoratorInternalInsets.top + Constants.nameSize.height / 2.0)

        let position = itemSize.skrullMap(point: originalPosition)
        let size = CGSize(width: itemSize.skrullMapX(Constants.iconSize),
                          height: itemSize.skrullMapY(Constants.iconSize))

        return SingleSkeleton(position: position, size: size).round()
    }

    private func createNameSkeleton(for itemSize: CGSize) -> Skeletonable {
        let originalX = Constants.decoratorInternalInsets.left + Constants.iconSize +
            Constants.iconNameSpacing + Constants.nameSize.width / 2.0

        let originalY = Constants.decoratorInternalInsets.top + Constants.nameSize.height / 2.0

        let cornerRadii = CGSize(width: Constants.nameSize.skrullMapX(Constants.nameSize.height / 2.0),
                                 height: Constants.nameSize.skrullMapY(Constants.nameSize.height / 2.0))

        return SingleSkeleton(position: CGPoint(x: itemSize.skrullMapX(originalX),
                                         y: itemSize.skrullMapY(originalY)),
                              size: CGSize(width: itemSize.skrullMapX(Constants.nameSize.width),
                                           height: itemSize.skrullMapY(Constants.nameSize.height)))
            .round(cornerRadii, mode: .allCorners)
    }

    private func createTimestampSkeleton(for itemSize: CGSize) -> Skeletonable {
        let originalX =  Constants.decoratorInternalInsets.right + Constants.timestampSize.width / 2.0

        let originalY = Constants.decoratorInternalInsets.top + Constants.timestampSize.height / 2.0

        let cornerRadii = CGSize(width: Constants.timestampSize.skrullMapX(Constants.timestampSize.height / 2.0),
                                 height: Constants.timestampSize.skrullMapY(Constants.timestampSize.height / 2.0))

        return SingleSkeleton(position: CGPoint(x: CGPoint.skrullBottomRight.x - itemSize.skrullMapX(originalX),
                                                y: itemSize.skrullMapY(originalY)),
                              size: CGSize(width: itemSize.skrullMapX(Constants.timestampSize.width),
                                           height: itemSize.skrullMapY(Constants.timestampSize.height)))
            .round(cornerRadii, mode: .allCorners)
    }

    private func createTitleSkeleton(for itemSize: CGSize) -> Skeletonable {
        let originX = Constants.decoratorInternalInsets.left + Constants.titleSize.width / 2.0

        let originY = Constants.decoratorInternalInsets.top + Constants.nameSize.height +
            Constants.titleNameSpacing + Constants.titleSize.height / 2.0

        let cornerRadii = CGSize(width: Constants.titleSize.skrullMapX(Constants.titleSize.height / 2.0),
                                 height: Constants.titleSize.skrullMapY(Constants.titleSize.height / 2.0))

        return SingleSkeleton(position: CGPoint(x: itemSize.skrullMapX(originX),
                                                y: itemSize.skrullMapY(originY)),
                              size: CGSize(width: itemSize.skrullMapX(Constants.titleSize.width),
                                           height: itemSize.skrullMapY(Constants.titleSize.height)))
            .round(cornerRadii, mode: .allCorners)
    }

    private func createTextSkeleton(for itemSize: CGSize) -> Skeletonable {
        let originY = Constants.decoratorInternalInsets.bottom + Constants.detailsHeight -
            Constants.detailsLineHeight / 2.0

        let originWidth = Constants.decoratorInternalInsets.left + Constants.decoratorInternalInsets.right

        return MultilineSkeleton(startLinePosition: CGPoint(x: CGPoint.skrullCenter.x,
                                                            y: itemSize.skrullMapY(itemSize.height - originY)),
                                 lineSize: CGSize(width: CGPoint.skrullBottomRight.x - itemSize.skrullMapX(originWidth),
                                                  height: itemSize.skrullMapY(Constants.detailsLineHeight)),
                                 count: 3,
                                 spacing: itemSize.skrullMapY(Constants.detailsLineSpacing))
            .round()
            .lastLine(fraction: Constants.detailsLastLineFraction)
    }
}
