/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

enum ActivityFeedPresenterError: Error {
    case unexpectedEmptyItemMetadata
    case unexpectedEmptyAnnouncementMetadata
    case unexpectedEmptyRewardCalculator
}

final class ActivityFeedPresenter {
    static let eventsPerPage: Int = 100

    enum DataState {
        case waitingCached
        case loading(page: Int)
        case loaded(page: Int, canLoadMore: Bool)
    }

	weak var view: ActivityFeedViewProtocol?
	var interactor: ActivityFeedInteractorInputProtocol!
	var wireframe: ActivityFeedWireframeProtocol!

    var itemViewModelFactory: ActivityFeedViewModelFactoryProtocol
    var announcementViewModelFactory: AnnouncementViewModelFactoryProtocol

    var logger: LoggerProtocol?

    private(set) var dataLoadingState: DataState = .waitingCached
    private(set) var viewModels: [ActivityFeedSectionViewModel] = []
    private(set) var uncommitedViewModels: [ActivityFeedSectionViewModel] = []
    private(set) var pages: [ActivityData] = []

    init(itemViewModelFactory: ActivityFeedViewModelFactoryProtocol,
         announcementViewModelFactory: AnnouncementViewModelFactoryProtocol) {
        self.itemViewModelFactory = itemViewModelFactory
        self.announcementViewModelFactory = announcementViewModelFactory
    }

    private func reloadView(with activity: ActivityData, andSwitch newDataLoadingState: DataState) throws {
        guard let layoutMetadataContainer = view?.itemLayoutMetadataContainer else {
            throw ActivityFeedPresenterError.unexpectedEmptyItemMetadata
        }

        uncommitedViewModels = [ActivityFeedSectionViewModel]()
        let newChanges = try itemViewModelFactory.merge(activity: activity,
                                                        into: &uncommitedViewModels,
                                                        using: layoutMetadataContainer)

        let commitedViewModels = uncommitedViewModels

        self.dataLoadingState = newDataLoadingState
        self.pages = [activity]

        let updateBlock = { () -> [ActivityFeedViewModelChange] in

            var changes = [ActivityFeedViewModelChange]()

            for (index, section) in self.viewModels.enumerated() {
                changes.append(ActivityFeedViewModelChange.delete(index: index, oldSection: section))
            }

            changes.append(contentsOf: newChanges)

            self.viewModels = commitedViewModels

            return changes
        }

        view?.didReceive(using: updateBlock)
    }

    private func appendPage(with activity: ActivityData, andSwitch newDataLoadingState: DataState) throws {
        guard let layoutMetadataContainer = view?.itemLayoutMetadataContainer else {
            throw ActivityFeedPresenterError.unexpectedEmptyItemMetadata
        }

        let newChanges = try itemViewModelFactory.merge(activity: activity,
                                                        into: &uncommitedViewModels,
                                                        using: layoutMetadataContainer)

        let commitedViewModels = uncommitedViewModels

        self.dataLoadingState = newDataLoadingState
        self.pages.append(activity)

        let updateBlock = { () -> [ActivityFeedViewModelChange] in
            self.viewModels = commitedViewModels

            return newChanges
        }

        view?.didReceive(using: updateBlock)
    }

    private func updateAnnouncementView(with data: AnnouncementData?) throws {
        guard let announcement = data else {
            view?.didReload(announcement: nil)
            return
        }

        guard let metadata = view?.announcementLayoutMetadata else {
            throw ActivityFeedPresenterError.unexpectedEmptyAnnouncementMetadata
        }

        let viewModel = announcementViewModelFactory.createAnnouncementViewModel(from: announcement,
                                                                                 using: metadata)

        view?.didReload(announcement: viewModel)
    }

    private func reloadActivityViewModels() throws {
        guard let layoutMetadataContainer = view?.itemLayoutMetadataContainer else {
            throw ActivityFeedPresenterError.unexpectedEmptyItemMetadata
        }

        uncommitedViewModels = [ActivityFeedSectionViewModel]()

        var newChanges = [ActivityFeedViewModelChange]()

        for activity in pages {
            let changes = try itemViewModelFactory.merge(activity: activity,
                                                         into: &uncommitedViewModels,
                                                         using: layoutMetadataContainer)
            newChanges.append(contentsOf: changes)
        }

        let commitedViewModels = uncommitedViewModels

        let updateBlock = { () -> [ActivityFeedViewModelChange] in

            var commitedChanges = [ActivityFeedViewModelChange]()

            for (index, section) in self.viewModels.enumerated() {
                commitedChanges.append(ActivityFeedViewModelChange.delete(index: index, oldSection: section))
            }

            commitedChanges.append(contentsOf: newChanges)

            self.viewModels = commitedViewModels

            return commitedChanges
        }

        view?.didReceive(using: updateBlock)
    }
}

extension ActivityFeedPresenter: ActivityFeedPresenterProtocol {
    var shouldDisplayEmptyState: Bool {
        switch dataLoadingState {
        case .waitingCached, .loading:
            return false
        case .loaded:
            return viewModels.count == 0
        }
    }

    func viewIsReady() {
        interactor.setup()
    }

    func viewDidAppear() {
        if case .loaded = dataLoadingState {
            interactor.reload()
        }
    }

    func reload() -> Bool {
        switch dataLoadingState {
        case .waitingCached:
            return false
        case .loading(let page) where page == 0:
            return false
        default:
            break
        }

        dataLoadingState = .loading(page: 0)

        interactor.reload()

        return true
    }

    func loadNext() -> Bool {
        switch dataLoadingState {
        case .waitingCached:
            return false
        case .loading(let page):
            return page > 0
        case .loaded(let lastPage, let canLoadMore):
            if canLoadMore {
                let newPage = lastPage + 1
                let page = Pagination(offset: newPage * ActivityFeedPresenter.eventsPerPage,
                                      count: ActivityFeedPresenter.eventsPerPage)

                dataLoadingState = .loading(page: newPage)
                interactor.loadNext(page: page)

                return true
            } else {
                return false
            }
        }
    }

    func numberOfSections() -> Int {
        return viewModels.count
    }

    func sectionModel(at index: Int) -> ActivityFeedSectionViewModelProtocol {
        return viewModels[index]
    }

    func activateHelp() {
        wireframe.presentHelp(from: view)
    }
}

extension ActivityFeedPresenter: ActivityFeedInteractorOutputProtocol {
    func didReload(activity: ActivityData?) {
        switch dataLoadingState {
        case .waitingCached:
            do {
                let loadedActivity = activity ?? ActivityData(events: [], users: [:], projects: [:])

                try reloadView(with: loadedActivity, andSwitch: .loading(page: 0))
                interactor.reload()
            } catch {
                logger?.error("Did receive cache processing error \(error)")
            }
        case .loading:
            do {
                if let loadedActivity = activity {
                    let canLoadMore = loadedActivity.events.count == ActivityFeedPresenter.eventsPerPage
                    try reloadView(with: loadedActivity, andSwitch: .loaded(page: 0, canLoadMore: canLoadMore))
                    interactor.reload()
                } else if pages.count > 0 {
                    let canLoadMore = pages[0].events.count == ActivityFeedPresenter.eventsPerPage
                    try reloadView(with: pages[0], andSwitch: .loaded(page: 0, canLoadMore: canLoadMore))
                } else {
                    logger?.error("Unconsistent data loading before cache")
                }
            } catch {
                logger?.debug("Did receive cache processing error \(error)")
            }
        case .loaded:
            do {
                if let loadedActivity = activity {
                    if let currentFirstPage = pages.first, currentFirstPage == loadedActivity {
                        logger?.debug("Cache update completed with same data")
                        return
                    }

                    let canLoadMore = loadedActivity.events.count == ActivityFeedPresenter.eventsPerPage
                    try reloadView(with: loadedActivity, andSwitch: .loaded(page: 0, canLoadMore: canLoadMore))
                }
            } catch {
                logger?.debug("Did receive cache processing error \(error)")
            }
        }
    }

    func didReceiveActivityFeedDataProvider(error: Error) {
        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Cache unexpectedly failed \(error)")
        case .loading:
            if pages.count > 0 {
                do {
                    let canLoadMore = pages[0].events.count == ActivityFeedPresenter.eventsPerPage
                    try reloadView(with: pages[0], andSwitch: .loaded(page: 0, canLoadMore: canLoadMore))
                } catch {
                    logger?.error("Unconsistent data loading before cache")
                }
            }

            if !wireframe.present(error: error, from: view) {
                logger?.debug("Cache refresh failed \(error)")
            }

        case .loaded:
            logger?.debug("Unexpected loading failed \(error)")
        }
    }

    func didLoadNext(activity: ActivityData, for page: Pagination) {
        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Unexpected page loading before cache")
        case .loading(let currentPage):
            let currentOffset = currentPage * ActivityFeedPresenter.eventsPerPage
            if currentOffset == page.offset {
                do {
                    let canLoadMore = activity.events.count == ActivityFeedPresenter.eventsPerPage
                    try appendPage(with: activity, andSwitch: .loaded(page: currentPage, canLoadMore: canLoadMore))
                } catch {
                    logger?.error("Did receive page processing error \(error)")
                }
            } else {
                logger?.debug("Unexpectedly loaded page \(page.offset) but expected \(currentPage)")
            }
        case .loaded:
            logger?.debug("Page \(page.offset) loaded but not waited")
        }
    }

    func didReceiveLoadNext(error: Error, for page: Pagination) {
        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Cached data expected but received page error \(error)")
        case .loading(let currentPage):
            let currentOffset = currentPage * ActivityFeedPresenter.eventsPerPage
            if currentOffset == page.offset {
                logger?.debug("Loading page \(currentPage) failed")

                if currentPage > 0 {
                    dataLoadingState = .loaded(page: currentPage - 1, canLoadMore: true)
                }
            } else {
                logger?.debug("Loading page \(page.offset) failed \(error) but expecting \(currentPage)")
            }
        case .loaded:
            logger?.debug("Loading page offset \(page.offset) failed \(error) but not waited")
        }
    }

    func didReload(announcement: AnnouncementData?) {
        do {
            try updateAnnouncementView(with: announcement)
        } catch {
            logger?.error("Unexpeted announcement update error \(error)")
        }
    }

    func didReceiveAnnouncementDataProvider(error: Error) {
        logger?.warning("Did receive announcement data provider error \(error)")
    }
}
