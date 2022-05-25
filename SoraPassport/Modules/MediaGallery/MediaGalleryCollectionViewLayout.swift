import UIKit

class MediaGalleryCollectionViewLayout: UICollectionViewFlowLayout {
    var pageSize: CGSize = CGSize.zero
    var velocityThresholdToChangePage: CGFloat = 0.01

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint,
                                      withScrollingVelocity velocity: CGPoint) -> CGPoint {
        let actualPageSize = pageSize != CGSize.zero ? pageSize : itemSize

        guard actualPageSize.width > 0.0 else {
            return proposedContentOffset
        }

        guard let currentCollectionView = collectionView else {
            return proposedContentOffset
        }

        var page = Int(round(proposedContentOffset.x / actualPageSize.width))
        let currentPage = Int(round(currentCollectionView.contentOffset.x / actualPageSize.width))

        if currentPage == page, abs(velocity.x) > CGFloat.leastNonzeroMagnitude,
            abs(velocity.x) > velocityThresholdToChangePage {
            page += Int(velocity.x / abs(velocity.x))
        }

        var targetOffsetX = CGFloat(page) * actualPageSize.width

        if targetOffsetX < 0.0 {
            targetOffsetX = 0.0
        }

        if targetOffsetX > currentCollectionView.contentSize.width - currentCollectionView.frame.size.width {
            targetOffsetX = floor(currentCollectionView.contentSize.width - currentCollectionView.frame.size.width)
        }

        return CGPoint(x: targetOffsetX, y: proposedContentOffset.y)
    }
}
