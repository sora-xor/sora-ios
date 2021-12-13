import UIKit
import RobinHood
import SoraUI

final class ActivityFeedViewController: UIViewController, AdaptiveDesignable, HiddableBarWhenPushed {
    private struct Constants {
        static let activityBasicCellId: String = "activityFeedBasicCellId"
        static let activityAmountCellId: String = "activityFeedAmountCellId"
        static let headerHeight: CGFloat = 73.0
        static let cellItemHeaderHeight: CGFloat = 54.0
        static let expandedHeaderHeight: CGFloat = 180.0
        static let compactHeaderHeight: CGFloat = 73.0
        static let collectionViewBottom: CGFloat = 20.0
        static let multiplierToActivateNextLoading: CGFloat = 1.5
        static let announcementIndexPath: IndexPath = IndexPath(item: 0, section: 0)
        static let emptyStateSection: Int = 1
        static let emptyStateIndexPath: IndexPath = IndexPath(item: 0, section: 1)
        static let emptyStateTopInsets: CGFloat = 40.0
        static let emptyStateSpacing: CGFloat = 40.0
    }

	var presenter: ActivityFeedPresenterProtocol!

    private(set) var announcementViewModel: AnnouncementItemViewModelProtocol?

    @IBOutlet private var collectionView: UICollectionView!
    private var headerView: ActivityFeedHeaderView?

    private(set) var itemLayoutMetadataContainer: ActivityFeedLayoutMetadataContainer = {
        return ActivityFeedLayoutMetadataContainer(basicLayoutMetadata: ActivityFeedItemLayoutMetadata(),
                                                   amountLayoutMetadata: ActivityFeedAmountItemLayoutMetadata())
    }()

    private(set) var announcementLayoutMetadata = AnnouncementItemLayoutMetadata()

    private var emptyItemsListViewModel: EmptyStateListViewModelProtocol?

    private var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(actionReload(sender:)), for: .valueChanged)
        return refreshControl
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        adjustLayout()
        configureCollectionView()
        setupCompactBar(with: .initial)

        presenter.viewIsReady()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.viewDidAppear()
    }

    private func adjustLayout() {
        itemLayoutMetadataContainer.basicLayoutMetadata = itemLayoutMetadataContainer.basicLayoutMetadata.with {
            $0.itemWidth *= self.designScaleRatio.width
        }

        itemLayoutMetadataContainer.amountLayoutMetadata = itemLayoutMetadataContainer.amountLayoutMetadata.with {
            $0.itemWidth *= self.designScaleRatio.width
        }

        announcementLayoutMetadata = announcementLayoutMetadata.with {
            $0.itemWidth *= self.designScaleRatio.width
        }
    }

    private func configureCollectionView() {
        collectionView.insertSubview(refreshControl, at: 0)

        collectionView.register(R.nib.activityFeedHeaderView,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader)
        collectionView.register(R.nib.activityFeedItemHeaderView,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader)

        collectionView.register(ActivityFeedCollectionViewCell.self,
                                forCellWithReuseIdentifier: Constants.activityBasicCellId)
        collectionView.register(ActivityFeedAmountCollectionViewCell.self,
                                forCellWithReuseIdentifier: Constants.activityAmountCellId)
        collectionView.register(R.nib.announcementCollectionViewCell)
        collectionView.register(EmptyStateCollectionViewCell.self,
                                forCellWithReuseIdentifier: EmptyStateListViewModel.cellIdentifier)

        var contentInset = collectionView.contentInset
        contentInset.bottom = Constants.collectionViewBottom
        collectionView.contentInset = contentInset

        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }

        let decoratorKind = NSStringFromClass(ActivityFeedSectionBackgroundView.self)
        layout.register(UINib(resource: R.nib.activityFeedSectionBackgroundView),
                        forDecorationViewOfKind: decoratorKind)

        layout.minimumLineSpacing = 0.0
        layout.minimumInteritemSpacing = 0.0
    }

    private func configureHeaderView(_ headerView: ActivityFeedHeaderView) {
        let actions = headerView.helpButton.actions(forTarget: self, forControlEvent: .touchUpInside) ?? []

        if actions.count == 0 {
            headerView.helpButton.addTarget(self,
                                            action: #selector(actionHelp(sender:)),
                                            for: .touchUpInside)
        }
    }

    private func updateCollectionViewDecoration() {
        guard let collectionViewLayout = collectionView.collectionViewLayout as? ActivityFeedCollectionFlowLayout else {
            return
        }

        collectionViewLayout.shouldDisplayDecoration = emptyItemsListViewModel == nil
    }

    // MARK: Empty State

    private func updateEmptyStateViewModel() {
        if presenter.shouldDisplayEmptyState {
            let spacing = isAdaptiveHeightDecreased ? Constants.emptyStateSpacing * designScaleRatio.height
                : Constants.emptyStateSpacing
            var displayInsets: UIEdgeInsets = .zero
            displayInsets.top = isAdaptiveHeightDecreased ? Constants.emptyStateTopInsets * designScaleRatio.height
                : Constants.emptyStateTopInsets

            emptyItemsListViewModel = EmptyStateListViewModel(image: R.image.activitiesEmptyIcon(),
                                                              title: R.string.localizable.activityEmptyTitle(),
                                                              spacing: spacing,
                                                              displayInsets: displayInsets)
        } else {
            clearEmptyStateViewModel()
        }
    }

    private func clearEmptyStateViewModel() {
        emptyItemsListViewModel = nil
    }

    // MARK: Actions

    @objc private func actionHelp(sender: AnyObject) {
        presenter.activateHelp()
    }

    @objc func actionReload(sender: AnyObject) {
        if !presenter.reload() {
            refreshControl.endRefreshing()
        }
    }
}

extension ActivityFeedViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if emptyItemsListViewModel == nil {
            return presenter.numberOfSections() + 1
        } else {
            return 2
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return announcementViewModel != nil ? 1 : 0
        } else {
            return emptyItemsListViewModel == nil ? presenter.sectionModel(at: section - 1).items.count : 1
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        if indexPath.section == 0 {
            return configureAnnouncementCell(collectionView, for: indexPath)
        } else if let emptyItemsListViewModel = emptyItemsListViewModel {
            return configureEmptyStateCell(collectionView, for: indexPath, viewModel: emptyItemsListViewModel)
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

            configureHeaderView(headerView)

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

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            return announcementItemSize
        } else if emptyItemsListViewModel != nil {
            return emptyStateViewItemSize
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
        } else {
            return activitySectionHeaderSize
        }
    }
}

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

extension ActivityFeedViewController: ActivityFeedViewProtocol {

    func didReceive(using viewModelChangeBlock: @escaping () -> [ActivityFeedViewModelChange]) {
        self.refreshControl.endRefreshing()

        let updateBlock = {
            let changes = viewModelChangeBlock()

            if self.emptyItemsListViewModel != nil {
                self.clearEmptyStateViewModel()
                self.collectionView.deleteSections([Constants.emptyStateSection])
            }

            self.updateCollectionViewDecoration()

            changes.forEach { self.applySection(change: $0) }
        }

        collectionView.performBatchUpdates(updateBlock, completion: nil)

        let emptyStateUpdateBlock = {
            self.updateEmptyStateViewModel()
            self.updateCollectionViewDecoration()

            if self.emptyItemsListViewModel != nil {
                self.collectionView.insertSections([Constants.emptyStateSection])
                self.collectionView.insertItems(at: [Constants.emptyStateIndexPath])
            }
        }

        collectionView.performBatchUpdates(emptyStateUpdateBlock, completion: nil)
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

extension ActivityFeedViewController: SoraCompactNavigationBarFloating {
    var compactBarSupportScrollView: UIScrollView {
        return collectionView
    }

    var compactBarTitle: String? {
        return R.string.localizable.tabbarActivityTitle()
    }
}

extension ActivityFeedViewController: ScrollsToTop {
    func scrollToTop() {
        var contentInsets = collectionView.contentInset

        if #available(iOS 11.0, *) {
            contentInsets = collectionView.adjustedContentInset
        }

        let contentOffset = CGPoint(x: 0.0, y: -contentInsets.top)
        collectionView.setContentOffset(contentOffset, animated: true)
    }
}
