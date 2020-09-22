/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI
import SoraFoundation

final class ProjectsViewController: UIViewController, AdaptiveDesignable, HiddableBarWhenPushed {
    struct Constants {
        static let projectCellSpacing: CGFloat = 20.0
        static let sectionHeight: CGFloat = 102.0
        static let emptyStateSpacing: CGFloat = 40.0

        static let headerSectionIndex = 0
        static let projectsSectionIndex = 1
    }

	var presenter: ProjectsPresenterProtocol!

    private(set) var headerView: ProjectHeaderView?
    private(set) var compactTopBar: ProjectCompactBar!
    @IBOutlet private(set) var collectionView: UICollectionView!

    private(set) var emptyStateViewModel: EmptyStateListViewModelProtocol?

    private(set) var projectLayoutMetadata = ProjectLayoutMetadata.createDefault()
    private(set) var referendumLayoutMetadata = ReferendumLayoutMetadata()

    private var segmentedControlTitles: [String] {
        let languages = localizationManager?.preferredLocalizations

        let allTitle = isAdaptiveWidthDecreased ?
            R.string.localizable.projectAllSmall(preferredLanguages: languages) :
            R.string.localizable.projectAll(preferredLanguages: languages)

        let votedTitle = isAdaptiveWidthDecreased ?
            R.string.localizable.projectVotedSmall(preferredLanguages: languages) :
            R.string.localizable.projectVoted(preferredLanguages: languages)

        let favoriteTitle = isAdaptiveWidthDecreased ?
            R.string.localizable.projectFavouritesSmall(preferredLanguages: languages) :
            R.string.localizable.projectFavourites(preferredLanguages: languages)

        let completedTitle = isAdaptiveWidthDecreased ?
            R.string.localizable.projectCompletedSmall(preferredLanguages: languages) :
            R.string.localizable.projectCompleted(preferredLanguages: languages)

        return [allTitle, votedTitle, favoriteTitle, completedTitle]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()

        presenter.setup(projectLayoutMetadata: projectLayoutMetadata,
                        referendumLayoutMetadata: referendumLayoutMetadata)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.viewDidAppear()
    }

    private func adjustLayout() {
        projectLayoutMetadata.adjust(using: self)
        referendumLayoutMetadata.adjust(using: self)

        if isAdaptiveWidthDecreased {
            compactTopBar.segmentedControlItemMargin *= designScaleRatio.width
        }
    }

    private func configure() {
        configureTopBar()
        configureCollectionView()
        setupLocalization()
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

        compactTopBar.segmentedControl.addTarget(self,
                                                 action: #selector(actionSegmentedControl(sender:)),
                                                 for: .valueChanged)

        compactTopBar.votesButton.addTarget(self,
                                            action: #selector(actionVotesButton(sender:)),
                                            for: .touchUpInside)
    }

    func configureHeaderView(_ headerView: ProjectHeaderView) {
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
        collectionView.register(R.nib.referendumCollectionViewCell)
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

            let image: UIImage?
            let title: String

            let languages = localizationManager?.preferredLocalizations

            switch presenter.displayType {
            case .all:
                image = R.image.openProjectsEmptyIcon()
                title = R.string.localizable
                    .emptyAllProjectDescription(preferredLanguages: languages)
            case .favorite:
                image = R.image.favProjectsEmptyIcon()
                title = R.string.localizable
                    .emptyFavoriteProjectDescription(preferredLanguages: languages)
            case .voted:
                image = R.image.votedProjectsEmptyIcon()
                title = R.string.localizable
                    .emptyVotedProjectDescription(preferredLanguages: languages)
            case .completed:
                image = R.image.compleProjectsEmptyIcon()
                title = R.string.localizable
                    .emptyCompletedProjectDescription(preferredLanguages: languages)
            }

            emptyStateViewModel = EmptyStateListViewModel(image: image,
                                                          title: title,
                                                          spacing: spacing,
                                                          displayInsets: displayInsets)

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

extension ProjectsViewController: Localizable {
    private func setupLocalization() {
        headerView?.segmentedControl.titles = segmentedControlTitles
        compactTopBar.segmentedControl.titles = segmentedControlTitles
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            updateEmptyStateViewModel()
            view.setNeedsLayout()
        }
    }
}
