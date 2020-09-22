import UIKit

extension ProjectsViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateScrollingState(at: scrollView.contentOffset, animated: true)
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let newContentOffset = completeScrolling(at: targetContentOffset.pointee, velocity: velocity, animated: true)
        targetContentOffset.pointee = newContentOffset
    }
}

extension ProjectsViewController: CompactBarFloating {
    var compactBarSupportScrollView: UIScrollView {
        return collectionView
    }

    var compactBar: UIView {
        return compactTopBar
    }
}

extension ProjectsViewController: ScrollsToTop {
    func scrollToTop() {
        var contentInsets = collectionView.contentInset

        if #available(iOS 11.0, *) {
            contentInsets = collectionView.adjustedContentInset
        }

        let contentOffset = CGPoint(x: 0.0, y: -contentInsets.top)
        collectionView.setContentOffset(contentOffset, animated: true)
    }
}
