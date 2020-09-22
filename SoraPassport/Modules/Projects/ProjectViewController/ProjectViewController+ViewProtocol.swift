import UIKit

extension ProjectsViewController: ProjectsViewProtocol {

    func didReloadProjects(using viewModelChangeBlock: @escaping () -> Void ) {
        let updateBlock = {
            viewModelChangeBlock()
            self.updateEmptyStateViewModel()
            self.collectionView.reloadSections([Constants.projectsSectionIndex])
        }

        collectionView.performBatchUpdates(updateBlock, completion: nil)
    }

    func didEditProjects(using viewModelChangeBlock: @escaping () -> ViewModelUpdateResult) {

        let updateBlock = {
            let modelChanges = viewModelChangeBlock()
            let updatedIndexes = modelChanges.updatedIndexes
            let deletedIndexes = modelChanges.deletedIndexes
            let insertedIndexes = modelChanges.insertedIndexes

            let oldEmptyStateViewModel = self.emptyStateViewModel
            self.updateEmptyStateViewModel()

            if oldEmptyStateViewModel != nil, self.emptyStateViewModel != nil {
                self.collectionView.reloadItems(at: [IndexPath(row: 0, section: Constants.projectsSectionIndex)])
            }

            if updatedIndexes.count > 0 {
                let updatedIndexPaths = updatedIndexes.map {
                    IndexPath(item: $0, section: Constants.projectsSectionIndex)
                }

                self.collectionView.reloadItems(at: updatedIndexPaths)
            }

            if oldEmptyStateViewModel != nil, self.emptyStateViewModel == nil {
                self.collectionView.deleteItems(at: [IndexPath(item: 0, section: Constants.projectsSectionIndex)])
            }

            if deletedIndexes.count > 0 {
                let deletedIndexPaths = deletedIndexes.map {
                    IndexPath(item: $0, section: Constants.projectsSectionIndex)
                }
                self.collectionView.deleteItems(at: deletedIndexPaths)
            }

            if oldEmptyStateViewModel == nil, self.emptyStateViewModel != nil {
                self.collectionView.insertItems(at: [IndexPath(row: 0, section: Constants.projectsSectionIndex)])
            }

            if insertedIndexes.count > 0 {
                let insertedIndexPaths = insertedIndexes.map {
                    IndexPath(item: $0, section: Constants.projectsSectionIndex)
                }

                self.collectionView.insertItems(at: insertedIndexPaths)
            }
        }

        collectionView.performBatchUpdates(updateBlock, completion: nil)
    }

    func didLoad(votes: String) {
        headerView?.votesButton.imageWithTitleView?.title = votes
        headerView?.votesButton.invalidateLayout()

        compactTopBar.votesButton.imageWithTitleView?.title = votes
        compactTopBar.votesButton.invalidateLayout()
    }
}
