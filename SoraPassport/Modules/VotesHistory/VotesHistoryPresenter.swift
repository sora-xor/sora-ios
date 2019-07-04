/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class VotesHistoryPresenter {
    static let eventsPerPage: Int = 100

    enum DataState {
        case waitingCached
        case loading(page: Int)
        case loaded(page: Int, canLoadMore: Bool)
    }

	weak var view: VotesHistoryViewProtocol?
	var interactor: VotesHistoryInteractorInputProtocol!
	var wireframe: VotesHistoryWireframeProtocol!

    var viewModelFactory: VotesHistoryViewModelFactoryProtocol

    var logger: LoggerProtocol?

    private(set) var dataLoadingState: DataState = .waitingCached
    private(set) var viewModels: [VotesHistorySectionViewModel] = []
    private(set) var pages: [[VotesHistoryEventData]] = []

    init(viewModelFactory: VotesHistoryViewModelFactoryProtocol) {
        self.viewModelFactory = viewModelFactory
    }

    private func reloadView(with events: [VotesHistoryEventData], andSwitch newDataLoadingState: DataState) throws {
        var viewModels = [VotesHistorySectionViewModel]()
        _ = try viewModelFactory.merge(newItems: events, into: &viewModels)

        self.dataLoadingState = newDataLoadingState
        self.pages = [events]
        self.viewModels = viewModels

        view?.didReload()
    }

    private func appendPage(with events: [VotesHistoryEventData], andSwitch newDataLoadingState: DataState) throws {
        var viewModels = self.viewModels
        let viewChanges = try viewModelFactory.merge(newItems: events, into: &viewModels)

        self.dataLoadingState = newDataLoadingState
        self.pages.append(events)
        self.viewModels = viewModels

        if viewChanges.count > 0 {
            view?.didReceive(changes: viewChanges)
        }
    }
}

extension VotesHistoryPresenter: VotesHistoryPresenterProtocol {
    var shouldDisplayEmptyState: Bool {
        switch dataLoadingState {
        case .waitingCached:
            return false
        case .loading:
            return false
        case .loaded:
            return pages.first?.count == 0
        }
    }

    func viewIsReady() {
        interactor.setup()
    }

    func reload() {
        switch dataLoadingState {
        case .waitingCached:
            return
        case .loading(let page):
            if page == 0 {
                return
            }
        default:
            break
        }

        dataLoadingState = .loading(page: 0)

        interactor.reload()
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
                let page = Pagination(offset: newPage * VotesHistoryPresenter.eventsPerPage,
                                      count: VotesHistoryPresenter.eventsPerPage)

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

    func sectionModel(at index: Int) -> VotesHistorySectionViewModelProtocol {
        return viewModels[index]
    }
}

extension VotesHistoryPresenter: VotesHistoryInteractorOutputProtocol {
    func didReload(events: [VotesHistoryEventData]?) {
        switch dataLoadingState {
        case .waitingCached:
            do {
                let loadedEvents = events ?? []
                try reloadView(with: loadedEvents, andSwitch: .loading(page: 0))
                interactor.reload()
            } catch {
                logger?.error("Did receive cache processing error \(error)")
            }
        case .loading, .loaded:
            do {
                if let loadedEvents = events {
                    let canLoadMore = loadedEvents.count == VotesHistoryPresenter.eventsPerPage
                    try reloadView(with: loadedEvents, andSwitch: .loaded(page: 0, canLoadMore: canLoadMore))
                    interactor.reload()
                } else if pages.count > 0 {
                    let canLoadMore = pages[0].count == VotesHistoryPresenter.eventsPerPage
                    try reloadView(with: pages[0], andSwitch: .loaded(page: 0, canLoadMore: canLoadMore))
                } else {
                    logger?.error("Unconsistent data loading before cache")
                }
            } catch {
                logger?.debug("Did receive cache processing error \(error)")
            }
        }
    }

    func didReceiveVotesHistoryDataProvider(error: Error) {
        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Cache unexpectedly failed \(error)")
        case .loading:
            if pages.count > 0 {
                do {
                    let canLoadMore = pages[0].count == VotesHistoryPresenter.eventsPerPage
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

    func didLoadNext(events: [VotesHistoryEventData], for page: Pagination) {
        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Unexpected page loading before cache")
        case .loading(let currentPage):
            let currentOffset = currentPage * VotesHistoryPresenter.eventsPerPage
            if currentOffset == page.offset {
                do {
                    let canLoadMore = events.count == VotesHistoryPresenter.eventsPerPage
                    try appendPage(with: events, andSwitch: .loaded(page: currentPage, canLoadMore: canLoadMore))
                } catch {
                    logger?.error("Did receive page processing error \(error)")
                }
            } else {
                logger?.debug("Unexpected loaded page offset \(page.offset) but expected \(currentOffset)")
            }
        case .loaded:
            logger?.debug("Page offset \(page.offset) loaded but not waited")
        }
    }

    func didReceiveLoadNext(error: Error, for page: Pagination) {
        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Cached data expected but received page error \(error)")
        case .loading(let currentPage):
            let currentOffset = currentPage * VotesHistoryPresenter.eventsPerPage

            if currentOffset == page.offset {
                logger?.debug("Loading page \(currentPage) failed")

                if currentPage > 0 {
                    dataLoadingState = .loaded(page: currentPage - 1, canLoadMore: true)
                }
            } else {
                logger?.debug("Loading page offset \(page.offset) failed \(error) but expecting \(currentOffset)")
            }
        case .loaded:
            logger?.debug("Loading page offset \(page.offset) failed \(error) but not waited")
        }
    }
}
