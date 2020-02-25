/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI
import SoraFoundation

extension ActivityFeedViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if emptyItemsListViewModel == nil && loadingViewModel == nil {
            return presenter.numberOfSections() + 1
        } else {
            return 2
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return announcementViewModel != nil ? 1 : 0
        } else {
            return emptyItemsListViewModel == nil && loadingViewModel == nil ?
                presenter.sectionModel(at: section - 1).items.count : 1
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        if indexPath.section == 0 {
            return configureAnnouncementCell(collectionView, for: indexPath)
        } else if let emptyItemsListViewModel = emptyItemsListViewModel {
            return configureEmptyStateCell(collectionView, for: indexPath, viewModel: emptyItemsListViewModel)
        } else if let loadingViewModel = loadingViewModel {
            return configureLoadingStateCell(collectionView, for: indexPath, viewModel: loadingViewModel)
        } else {
            return configureActivityCell(collectionView, for: indexPath)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        if indexPath.section == 0 {
            let headerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: R.reuseIdentifier.activityFeedHeaderId,
                for: indexPath)!

            configureCollectionViewHeader(headerView)

            return headerView
        } else {
            let itemHeaderView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: R.reuseIdentifier.activityItemHeaderId,
                for: indexPath)!

            let section = presenter.sectionModel(at: indexPath.section - 1)
            itemHeaderView.titleLabel.text = section.title

            return itemHeaderView
        }
    }

    private func configureAnnouncementCell(_ collectionView: UICollectionView,
                                           for indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.announcementCellId,
                                                      for: indexPath)!

        if let announcement = announcementViewModel {
            cell.bind(viewModel: announcement)
        }

        cell.localizationManager = localizationManager

        return cell
    }

    // swiftlint:disable force_cast
    private func configureActivityCell(_ collectionView: UICollectionView,
                                       for indexPath: IndexPath) -> UICollectionViewCell {
        let section = presenter.sectionModel(at: indexPath.section - 1)

        switch section.items[indexPath.row] {
        case .basic(let concreteViewModel):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.activityBasicCellId,
                                                          for: indexPath) as! ActivityFeedCollectionViewCell

            cell.bind(viewModel: concreteViewModel, with: itemLayoutMetadataContainer.basicLayoutMetadata)

            return cell

        case .amount(let concreteViewModel):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.activityAmountCellId,
                                                          for: indexPath) as! ActivityFeedAmountCollectionViewCell

            cell.bind(viewModel: concreteViewModel, with: itemLayoutMetadataContainer.amountLayoutMetadata)

            return cell
        }
    }

    private func configureEmptyStateCell(_ collectionView: UICollectionView,
                                         for indexPath: IndexPath,
                                         viewModel: EmptyStateListViewModelProtocol) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmptyStateListViewModel.cellIdentifier,
                                                      for: indexPath) as! EmptyStateCollectionViewCell

        cell.bind(viewModel: viewModel)

        return cell
    }

    private func configureLoadingStateCell(_ collectionView: UICollectionView,
                                           for indexPath: IndexPath,
                                           viewModel: SkeletonCellViewModel) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.skeletonCellId,
                                                      for: indexPath) as! SkeletonCollectionViewCell

        cell.present(for: viewModel)

        return cell
    }

    // swiftlint:enable force_cast
}

extension ActivityFeedViewController: UICollectionViewDelegateFlowLayout {
    private var announcementItemSize: CGSize {
        guard let announcement = announcementViewModel else {
            return .zero
        }

        return announcement.layout.itemSize
    }

    private func activityItemSize(for indexPath: IndexPath) -> CGSize {
        let section = presenter.sectionModel(at: indexPath.section - 1)

        switch section.items[indexPath.row] {
        case .basic(let concreteViewModel):
            return concreteViewModel.layout.itemSize
        case .amount(let concreteViewModel):
            return concreteViewModel.layout.itemSize
        }
    }

    private var emptyStateViewItemSize: CGSize {
        var emptyOffset = UIApplication.shared.statusBarFrame.size.height
        emptyOffset += Constants.headerHeight
        emptyOffset += Constants.collectionViewBottom

        if let announcement = announcementViewModel {
            emptyOffset += announcement.layout.itemSize.height
        }

        return CGSize(width: collectionView.frame.size.width,
                      height: collectionView.frame.size.height - emptyOffset)
    }

    private var mainHeaderSize: CGSize {
        return CGSize(width: collectionView.frame.size.width,
                      height: Constants.headerHeight)
    }

    private var activitySectionHeaderSize: CGSize {
        return CGSize(width: collectionView.frame.size.width,
                      height: Constants.cellItemHeaderHeight)
    }

    private var skeletonItemSize: CGSize {
        var emptyOffset = UIApplication.shared.statusBarFrame.size.height
        emptyOffset += Constants.headerHeight
        emptyOffset += Constants.collectionViewBottom

        if let announcement = announcementViewModel {
            emptyOffset += announcement.layout.itemSize.height
        }

        return CGSize(width: collectionView.frame.size.width,
                      height: collectionView.frame.size.height - emptyOffset)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            return announcementItemSize
        } else if emptyItemsListViewModel != nil {
            return emptyStateViewItemSize
        } else if loadingViewModel != nil {
            return skeletonItemSize
        } else {
            return activityItemSize(for: indexPath)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 0 {
            return mainHeaderSize
        } else if emptyItemsListViewModel != nil {
            return .zero
        } else if loadingViewModel != nil {
            return .zero
        } else {
            return activitySectionHeaderSize
        }
    }
}
