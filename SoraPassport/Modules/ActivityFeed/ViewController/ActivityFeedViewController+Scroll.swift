/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraFoundation

extension ActivityFeedViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var threshold = scrollView.contentSize.height
        threshold -= scrollView.bounds.height * Constants.multiplierToActivateNextLoading

        if scrollView.contentOffset.y > threshold {
            _ = presenter.loadNext()
        }

        updateScrollingState(at: scrollView.contentOffset, animated: true)
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let newContentOffset = completeScrolling(at: targetContentOffset.pointee, velocity: velocity, animated: true)
        targetContentOffset.pointee = newContentOffset
    }
}

extension ActivityFeedViewController: SoraCompactNavigationBarFloating {
    var compactBarSupportScrollView: UIScrollView {
        return collectionView
    }

    var compactBarTitle: String? {
        let languages = localizationManager?.preferredLocalizations
        return R.string.localizable.tabbarActivityTitle(preferredLanguages: languages)
    }
}
