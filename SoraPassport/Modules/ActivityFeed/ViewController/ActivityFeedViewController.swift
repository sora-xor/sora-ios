import UIKit
import RobinHood
import SoraUI
import SoraFoundation

final class ActivityFeedViewController: UIViewController, AdaptiveDesignable, HiddableBarWhenPushed {
    struct Constants {
        static let activityBasicCellId: String = "activityFeedBasicCellId"
        static let activityAmountCellId: String = "activityFeedAmountCellId"
        static let skeletonCellId: String = "activitySkeletonCellId"
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
        static let loadingStateSection: Int = 1
        static let loadingStateIndexPath: IndexPath = IndexPath(item: 0, section: 1)
        static let skeletonItemPrefferedHeight: CGFloat = 212.0
        static let skeletonContentWidth: CGFloat = 375.0
        static let skeletonVerticalSpacing: CGFloat = 50.0
        static let skeletonContentInsets: UIEdgeInsets = UIEdgeInsets(top: 0.0,
                                                                      left: 20.0,
                                                                      bottom: 20.0,
                                                                      right: 20.0)
    }

	var presenter: ActivityFeedPresenterProtocol!

    @IBOutlet private(set) var collectionView: UICollectionView!
    private(set) var headerView: ActivityFeedHeaderView?

    private(set) var itemLayoutMetadataContainer: ActivityFeedLayoutMetadataContainer = {
        return ActivityFeedLayoutMetadataContainer(basicLayoutMetadata: ActivityFeedItemLayoutMetadata(),
                                                   amountLayoutMetadata: ActivityFeedAmountItemLayoutMetadata())
    }()

    private(set) var announcementLayoutMetadata = AnnouncementItemLayoutMetadata()

    var announcementViewModel: AnnouncementItemViewModelProtocol?
    var emptyItemsListViewModel: EmptyStateListViewModelProtocol?
    var loadingViewModel: SkeletonCellViewModel?

    private(set) var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(actionReload(sender:)), for: .valueChanged)
        return refreshControl
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        adjustLayout()
        configureCollectionView()
        setupCompactBar(with: .initial)

        presenter.setup()
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

        collectionView.register(ActivityFeedSkeletonViewCell.self,
                                forCellWithReuseIdentifier: Constants.skeletonCellId)

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

    // MARK: Collection View

    func configureCollectionViewHeader(_ headerView: ActivityFeedHeaderView) {
        let actions = headerView.helpButton.actions(forTarget: self, forControlEvent: .touchUpInside) ?? []

        if actions.count == 0 {
            headerView.helpButton.addTarget(self,
                                            action: #selector(actionHelp(sender:)),
                                            for: .touchUpInside)
        }

        headerView.localizationManager = localizationManager
    }

    func updateCollectionViewDecoration() {
        guard let collectionViewLayout = collectionView.collectionViewLayout as? ActivityFeedCollectionFlowLayout else {
            return
        }

        collectionViewLayout.shouldDisplayDecoration = emptyItemsListViewModel == nil && loadingViewModel == nil
    }

    // MARK: Collection View State

    func updateDisplay(for state: ActivityFeedViewState) {
        switch state {
        case .data:
            clearEmptyStateViewModel()
            clearLoadingStateViewModel()
        case .empty:
            clearLoadingStateViewModel()
            setupEmptyStateViewModel()
        case .loading:
            clearEmptyStateViewModel()
            setupLoadingViewModel()
        }
    }

    // MARK: Empty State

    func setupEmptyStateViewModel() {
        let spacing = isAdaptiveHeightDecreased ? Constants.emptyStateSpacing * designScaleRatio.height
            : Constants.emptyStateSpacing
        var displayInsets: UIEdgeInsets = .zero
        displayInsets.top = isAdaptiveHeightDecreased ? Constants.emptyStateTopInsets * designScaleRatio.height
            : Constants.emptyStateTopInsets

        let title = R.string.localizable
            .activityEmptyDescription(preferredLanguages: localizationManager?.preferredLocalizations)
        emptyItemsListViewModel = EmptyStateListViewModel(image: R.image.activitiesEmptyIcon(),
                                                          title: title,
                                                          spacing: spacing,
                                                          displayInsets: displayInsets)
    }

    func clearEmptyStateViewModel() {
        emptyItemsListViewModel = nil
    }

    // MARK: Skeleton State

    func setupLoadingViewModel() {
        var skeletonSize = CGSize(width: Constants.skeletonContentWidth * designScaleRatio.width,
                                  height: baseDesignSize.height * designScaleRatio.height)
        skeletonSize.height -= UIApplication.shared.statusBarFrame.size.height
        skeletonSize.height -= Constants.headerHeight

        loadingViewModel = SkeletonCellViewModel(contentSize: skeletonSize)
    }

    func clearLoadingStateViewModel() {
        loadingViewModel = nil
    }

    // MARK: Actions

    @objc private func actionHelp(sender: AnyObject) {
        presenter.activateHelp()
    }

    @objc func actionReload(sender: AnyObject) {
        let didStartReloading = presenter.reload()

        if !didStartReloading {
            refreshControl.endRefreshing()
        }
    }
}

extension ActivityFeedViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else {
            return
        }

        if emptyItemsListViewModel != nil {
            setupEmptyStateViewModel()
            collectionView.reloadData()
        }

        reloadCompactBar()
    }
}
