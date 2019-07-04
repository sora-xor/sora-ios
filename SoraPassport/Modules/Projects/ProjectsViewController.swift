/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

final class ProjectsViewController: UIViewController, AdaptiveDesignable, HiddableBarWhenPushed {
    private struct Constants {
        static let projectCellSpacing: CGFloat = 20.0
        static let sectionHeight: CGFloat = 102.0
        static let emptyStateSpacing: CGFloat = 40.0

        static let headerSectionIndex = 0
        static let projectsSectionIndex = 1
    }

	var presenter: ProjectsPresenterProtocol!

    private var headerView: ProjectHeaderView?
    private var compactTopBar: ProjectCompactBar!
    @IBOutlet private var collectionView: UICollectionView!

    private var emptyStateViewModel: EmptyStateListViewModelProtocol?

    private var layoutMetadata = ProjectLayoutMetadata.createDefault()

    private var segmentedControlTitles: [String] {
        let allTitle = isAdaptiveWidthDecreased ? R.string.localizable.projectAllSmallTitle() :
        R.string.localizable.projectAllTitle()

        let votedTitle = isAdaptiveWidthDecreased ? R.string.localizable.projectVotedSmallTitle() :
            R.string.localizable.projectVotedTitle()

        let favoriteTitle = isAdaptiveWidthDecreased ? R.string.localizable.projectFavoriteSmallTitle() :
            R.string.localizable.projectFavoriteTitle()

        let completedTitle = isAdaptiveWidthDecreased ? R.string.localizable.projectCompletedSmallTitle() :
            R.string.localizable.projectCompletedTitle()

        return [allTitle, votedTitle, favoriteTitle, completedTitle]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()

        presenter.viewIsReady(layoutMetadata: layoutMetadata)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.viewDidAppear()
    }

    private func adjustLayout() {
        layoutMetadata.adjust(using: self)

        if isAdaptiveWidthDecreased {
            compactTopBar.segmentedControlWidth *= designScaleRatio.width
            compactTopBar.segmentedControlItemMargin *= designScaleRatio.width
        }
    }

    private func configure() {
        configureTopBar()
        configureCollectionView()
        adjustLayout()

        hideCompactTopBar(animated: false)
    }

    private func configureTopBar() {
        compactTopBar = R.nib.projectCompactBar.firstView(owner: nil)!
        setupCompactBar(with: .initial)

        let height = UIApplication.shared.statusBarFrame.size.height +
            navigationController!.navigationBar.frame.size.height

        compactTopBar.frame = CGRect(x: 0.0,
                                     y: 0.0,
                                     width: view.frame.size.width,
                                     height: height)
        compactTopBar.autoresizingMask = .flexibleWidth

        compactTopBar.segmentedControl.titles = segmentedControlTitles
        compactTopBar.segmentedControl.addTarget(self,
                                                 action: #selector(actionSegmentedControl(sender:)),
                                                 for: .valueChanged)

        compactTopBar.votesButton.addTarget(self,
                                            action: #selector(actionVotesButton(sender:)),
                                            for: .touchUpInside)
    }

    private func configureHeaderView(_ headerView: ProjectHeaderView) {
        headerView.segmentedControl.titles = segmentedControlTitles

        if let currentHeaderView = self.headerView {
            headerView.segmentedControl.selectedSegmentIndex = currentHeaderView.segmentedControl.selectedSegmentIndex
            headerView.votesButton.imageWithTitleView?.title = currentHeaderView.votesButton.imageWithTitleView?.title
        }

        headerView.helpButton.addTarget(self,
                                        action: #selector(actionHelpButton(sender:)),
                                        for: .touchUpInside)

        headerView.votesButton.addTarget(self,
                                        action: #selector(actionVotesButton(sender:)),
                                        for: .touchUpInside)

        headerView.segmentedControl.addTarget(self,
                                              action: #selector(actionSegmentedControl(sender:)),
                                              for: .valueChanged)

        self.headerView = headerView
    }

    private func configureCollectionView() {
        collectionView.register(EmptyStateCollectionViewCell.self,
                                forCellWithReuseIdentifier: EmptyStateListViewModel.cellIdentifier)
        collectionView.register(R.nib.openProjectCollectionViewCell)
        collectionView.register(R.nib.finishedProjectCollectionViewCell)
        collectionView.register(R.nib.projectHeaderView,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader)

        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }

        layout.minimumLineSpacing = Constants.projectCellSpacing
        layout.minimumInteritemSpacing = Constants.projectCellSpacing

        layout.sectionInset = UIEdgeInsets(top: 0.0,
                                           left: 0.0,
                                           bottom: Constants.projectCellSpacing,
                                           right: 0.0)
    }

    // MARK: Empty State

    func updateEmptyStateViewModel() {
        if presenter.shouldDisplayEmptyState {
            let spacing = isAdaptiveHeightDecreased ? Constants.emptyStateSpacing * designScaleRatio.height
                : Constants.emptyStateSpacing
            var displayInsets: UIEdgeInsets = .zero
            displayInsets.top = spacing

            switch presenter.displayType {
            case .all:
                emptyStateViewModel = EmptyStateListViewModel(image: R.image.openProjectsEmptyIcon(),
                                                              title: R.string.localizable.projectEmptyOpenedTitle(),
                                                              spacing: spacing,
                                                              displayInsets: displayInsets)
            case .favorite:
                emptyStateViewModel = EmptyStateListViewModel(image: R.image.favProjectsEmptyIcon(),
                                                              title: R.string.localizable.projectEmptyFavoriteTitle(),
                                                              spacing: spacing,
                                                              displayInsets: displayInsets)
            case .voted:
                emptyStateViewModel = EmptyStateListViewModel(image: R.image.votedProjectsEmptyIcon(),
                                                              title: R.string.localizable.projectEmptyVotedTitle(),
                                                              spacing: spacing,
                                                              displayInsets: displayInsets)
            case .completed:
                emptyStateViewModel = EmptyStateListViewModel(image: R.image.compleProjectsEmptyIcon(),
                                                              title: R.string.localizable.projectEmptyCompletedTitle(),
                                                              spacing: spacing,
                                                              displayInsets: displayInsets)
            }

        } else {
            emptyStateViewModel = nil
        }
    }

    // MARK: Actions

    @objc private func actionVotesButton(sender: AnyObject) {
        presenter.activateVotesDetails()
    }

    @objc private func actionSegmentedControl(sender: AnyObject) {
        guard let segmentedControl = sender as? PlainSegmentedControl else {
            return
        }

        compactTopBar.segmentedControl.selectedSegmentIndex = segmentedControl.selectedSegmentIndex
        headerView?.segmentedControl.selectedSegmentIndex = segmentedControl.selectedSegmentIndex

        guard let displayType = ProjectDisplayType(rawValue: segmentedControl.selectedSegmentIndex) else {
            return
        }

        presenter.activateProjectDisplay(type: displayType)
    }

    @objc private func actionHelpButton(sender: AnyObject) {
        presenter.activateHelp()
    }

    @IBAction private func actionSwipeLeft(sender: AnyObject) {
        let selectedIndex = compactTopBar.segmentedControl.selectedSegmentIndex

        if selectedIndex < compactTopBar.segmentedControl.numberOfSegments - 1 {
            compactTopBar.segmentedControl.selectedSegmentIndex = selectedIndex + 1
            headerView?.segmentedControl.selectedSegmentIndex = selectedIndex + 1

            guard let displayType = ProjectDisplayType(rawValue: selectedIndex + 1) else {
                return
            }

            presenter.activateProjectDisplay(type: displayType)
        }
    }

    @IBAction private func actionSwipeRight(sender: AnyObject) {
        let selectedIndex = compactTopBar.segmentedControl.selectedSegmentIndex

        if selectedIndex > 0 {
            compactTopBar.segmentedControl.selectedSegmentIndex = selectedIndex - 1
            headerView?.segmentedControl.selectedSegmentIndex = selectedIndex - 1

            guard let displayType = ProjectDisplayType(rawValue: selectedIndex - 1) else {
                return
            }

            presenter.activateProjectDisplay(type: displayType)
        }
    }
}

extension ProjectsViewController: UICollectionViewDataSource {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == Constants.headerSectionIndex {
            return 0
        } else {
            guard emptyStateViewModel == nil else {
                return 1
            }

            return presenter.numberOfProjects
        }
    }

    public func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let emptyStateViewModel = emptyStateViewModel {
            return configureEmptyStateCell(for: collectionView,
                                           indexPath: indexPath,
                                           viewModel: emptyStateViewModel)
        } else {
            let oneOfViewModel = presenter.viewModel(at: indexPath.row)

            switch oneOfViewModel {
            case .open(let viewModel):
                return configureOpenProjectCell(for: collectionView,
                                                indexPath: indexPath,
                                                viewModel: viewModel)
            case .finished(let viewModel):
                return configureFinishedProjectCell(for: collectionView,
                                                    indexPath: indexPath,
                                                    viewModel: viewModel)
            }
        }
    }

    private func configureOpenProjectCell(for collectionView: UICollectionView,
                                          indexPath: IndexPath,
                                          viewModel: OpenProjectViewModelProtocol) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.openProjectCellId,
                                                      for: indexPath)!

        cell.bind(viewModel: viewModel, layoutMetadata: layoutMetadata.openProjectLayoutMetadata)

        return cell
    }

    private func configureFinishedProjectCell(for collectionView: UICollectionView,
                                              indexPath: IndexPath,
                                              viewModel: FinishedProjectViewModelProtocol) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.finishedProjectCellId,
                                                      for: indexPath)!

        cell.bind(viewModel: viewModel, layoutMetadata: layoutMetadata.finishedProjectLayoutMetadata)

        return cell
    }

    //swiftlint:disable force_cast
    private func configureEmptyStateCell(for collectionView: UICollectionView,
                                         indexPath: IndexPath,
                                         viewModel: EmptyStateListViewModelProtocol) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmptyStateListViewModel.cellIdentifier,
                                                      for: indexPath) as! EmptyStateCollectionViewCell

        cell.bind(viewModel: viewModel)

        return cell
    }
    //swiftlint:enable force_cast

    public func collectionView(_ collectionView: UICollectionView,
                               viewForSupplementaryElementOfKind kind: String,
                               at indexPath: IndexPath) -> UICollectionReusableView {
        let projectHeaderView = collectionView
            .dequeueReusableSupplementaryView(ofKind: kind,
                                              withReuseIdentifier: R.reuseIdentifier.projectHeaderId,
                                              for: indexPath)!

        if self.headerView !== projectHeaderView {
            configureHeaderView(projectHeaderView)
        }

        return projectHeaderView
    }
}

extension ProjectsViewController: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)

        guard emptyStateViewModel == nil else {
            return
        }

        presenter.activateProject(at: indexPath.row)
    }
}

extension ProjectsViewController: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               sizeForItemAt indexPath: IndexPath) -> CGSize {

        if emptyStateViewModel == nil {
            let model = presenter.viewModel(at: indexPath.row)

            return model.itemSize
        } else {
            var headerHeight = headerView?.frame.size.height ?? 0.0
            headerHeight = collectionView.frame.size.height - headerHeight
            headerHeight -= 2.0 * Constants.projectCellSpacing
            headerHeight -= UIApplication.shared.statusBarFrame.maxY

            return CGSize(width: collectionView.frame.size.width,
                          height: headerHeight)
        }
    }

    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == Constants.headerSectionIndex {
            return CGSize(width: collectionView.frame.size.width, height: Constants.sectionHeight)
        } else {
            return .zero
        }
    }
}

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
