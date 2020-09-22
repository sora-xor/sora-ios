/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

extension ActivityFeedViewController: ActivityFeedViewProtocol {

    func didReceive(using viewModelChangeBlock: @escaping () -> ActivityFeedStateChange) {
        self.refreshControl.endRefreshing()

        var optionalDisplayState: ActivityFeedViewState?

        let updateBlock = {
            let update = viewModelChangeBlock()

            if self.emptyItemsListViewModel != nil {
                self.clearEmptyStateViewModel()
                self.collectionView.deleteSections([Constants.emptyStateSection])
            }

            if self.loadingViewModel != nil {
                self.clearLoadingStateViewModel()
                self.collectionView.deleteSections([Constants.loadingStateSection])
            }

            self.updateCollectionViewDecoration()

            update.changes.forEach { self.applySection(change: $0) }

            optionalDisplayState = update.state
        }

        collectionView.performBatchUpdates(updateBlock, completion: nil)

        let displayStateUpdateBlock = {
            if let displayState = optionalDisplayState {
                self.updateDisplay(for: displayState)
            }

            self.updateCollectionViewDecoration()

            if self.emptyItemsListViewModel != nil {
                self.collectionView.insertSections([Constants.emptyStateSection])
                self.collectionView.insertItems(at: [Constants.emptyStateIndexPath])
            }

            if self.loadingViewModel != nil {
                self.collectionView.insertSections([Constants.loadingStateSection])
                self.collectionView.insertItems(at: [Constants.loadingStateIndexPath])
            }
        }

        collectionView.performBatchUpdates(displayStateUpdateBlock, completion: nil)
    }

    func didReload(announcement: AnnouncementItemViewModelProtocol?) {
        let updateBlock = {
            let oldAnnouncement = self.announcementViewModel
            self.announcementViewModel = announcement

            let announcementIndexPath = Constants.announcementIndexPath

            if oldAnnouncement != nil, announcement != nil {
                self.collectionView.reloadItems(at: [announcementIndexPath])
            } else if oldAnnouncement != nil, announcement == nil {
                self.collectionView.deleteItems(at: [announcementIndexPath])
            } else if oldAnnouncement == nil, announcement != nil {
                self.collectionView.insertItems(at: [announcementIndexPath])
            }
        }

        collectionView.performBatchUpdates(updateBlock, completion: nil)
    }

    private func applySection(change: ActivityFeedViewModelChange) {
        switch change {
        case .insert(let index, _):
            collectionView.insertSections([index + 1])
        case .update(let sectionIndex, let itemChange, _):
            applyRow(change: itemChange, for: sectionIndex + 1)
        case .delete(let index, _):
            collectionView.deleteSections([index + 1])
        }
    }

    private func applyRow(change: ListDifference<ActivityFeedOneOfItemViewModel>, for sectionIndex: Int) {
        switch change {
        case .insert(let index, _):
            collectionView.insertItems(at: [IndexPath(row: index, section: sectionIndex)])
        case .update(let index, _, _):
            collectionView.reloadItems(at: [IndexPath(row: index, section: sectionIndex)])
        case .delete(let index, _):
            collectionView.deleteItems(at: [IndexPath(row: index, section: sectionIndex)])
        }
    }
}
