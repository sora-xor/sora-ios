// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import SoraUIKit

import SoraFoundation

final class ActivityViewModel {
    @Published var snapshot: ActivitySnapshot = ActivitySnapshot()
    var snapshotPublisher: Published<ActivitySnapshot>.Publisher { $snapshot }

    var setupEmptyLabel: (() -> Void)?
    var setupErrorContent: (() -> Void)?
    var hideErrorContent: (() -> Void)?

    weak var view: ActivityViewProtocol?
    var sections: [ActivitySection] = []
    let historyService: HistoryServiceProtocol
    var viewModelFactory: ActivityViewModelFactoryProtocol
    let eventCenter: EventCenterProtocol
    let wireframe: ActivityWireframeProtocol
    let assetManager: AssetManagerProtocol
    var assetId: String?
    var title: String = ""
    var isNeedCloseButton: Bool = false
    var pageNumber = 0
    private var task: Task<Void, Swift.Error>?

    /// Where the pages on screen came from.
    enum ShownPages: Equatable {
        case none
        /// Read from the indexer when they were loaded.
        case current
        /// The saved copy, because the indexer could not be read. The date
        /// is when the last page shown was saved.
        case saved(Date)
    }

    private(set) var shownPages: ShownPages = .none

    /// How long a list that is behind waits before it asks for page 1
    /// again by itself: 15 s, then twice as long each time, 5 minutes at
    /// most. One try is one history read.
    static func refreshDelay(afterFailures failures: Int) -> TimeInterval {
        min(300, 15 * pow(2, Double(max(0, min(failures, 8)))))
    }

    /// Coming back to the screen does not ask again when page 1 was
    /// answered less than this long ago.
    static let minimumRefreshSpacing: TimeInterval = 15

    /// The list on screen is behind: page 1 is the saved copy, or page 1
    /// could not be loaded at all. While this is so, page 1 is asked for
    /// again after `refreshDelay`, when the app comes to the foreground and
    /// when the screen is shown again, until a current page 1 arrives.
    private(set) var isBehind = false
    private let refreshDelay: (Int) -> TimeInterval
    private let notificationCenter: NotificationCenter
    private var foregroundObserver: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?
    private var isRefreshing = false
    private var refreshFailures = 0
    /// Seconds on a clock that only runs forward.
    private let uptime: () -> TimeInterval
    /// `uptime()` when page 1 was last answered or failed.
    private var firstPageEndedAt: TimeInterval?
    /// Each list that is started gets the next number. A page that was
    /// asked for one list is never put into another.
    private var listNumber = 0
    /// The "Some data is not up to date / Refresh" row at the end of the
    /// list, while it is shown.
    private var retryRow: ActivitySection?
    /// The last page on screen is the last one there is: scrolling to the
    /// end of the list asks for nothing.
    private var endReached = false

    /// Whether a page may be put under the pages on screen.
    ///
    /// Rows move down the list as new transactions arrive, and each saved
    /// page keeps the rows it had when it was saved. A current page under
    /// saved ones, a saved page under current ones, or a saved page older
    /// than the one above it would show some rows twice or leave some out
    /// without a word.
    static func continues(_ shown: ShownPages, pageCachedAt: Date?) -> Bool {
        switch (shown, pageCachedAt) {
        case (.none, _), (.current, nil):
            return true
        case (.current, .some), (.saved, nil):
            return false
        case let (.saved(above), .some(date)):
            return date >= above
        }
    }

    init(historyService: HistoryServiceProtocol,
         viewModelFactory: ActivityViewModelFactoryProtocol,
         wireframe: ActivityWireframeProtocol,
         assetManager: AssetManagerProtocol,
         eventCenter: EventCenterProtocol,
         assetId: String? = nil,
         notificationCenter: NotificationCenter = .default,
         refreshDelay: @escaping (Int) -> TimeInterval = ActivityViewModel.refreshDelay(afterFailures:),
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.historyService = historyService
        self.viewModelFactory = viewModelFactory
        self.eventCenter = eventCenter
        self.wireframe = wireframe
        self.assetManager = assetManager
        self.assetId = assetId
        self.notificationCenter = notificationCenter
        self.refreshDelay = refreshDelay
        self.uptime = uptime
        self.eventCenter.add(observer: self)
        foregroundObserver = notificationCenter.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // The app was away, so the network may be back: start the
            // waits from the short end again.
            self?.refreshNowIfBehind(startingOver: true)
        }
    }

    deinit {
        refreshTask?.cancel()
        if let foregroundObserver {
            notificationCenter.removeObserver(foregroundObserver)
        }
    }
}

extension ActivityViewModel: ActivityViewModelProtocol {
    func viewDidLoad() {
        guard sections.isEmpty else { return }

        sections = viewModelFactory.createActivityShimmerModels()
        snapshot = createSnapshot()
        Task { [weak self] in
            await self?.loadContent()
        }
    }

    func updateContent() {
        // Page 1 is loaded by `viewDidLoad` and `resetPagination`, and
        // nothing comes after a list that ended: no spinner for either.
        guard pageNumber > 0, !endReached else { return }

        view?.startPaginationLoader()
        Task { [weak self] in
            await self?.loadContent()
        }
    }

    private func incrementPage() {
        pageNumber += 1
    }

    private func reload() {
        incrementPage()
        view?.stopPaginationLoader()
        snapshot = createSnapshot()
    }

    private func createSnapshot() -> ActivitySnapshot {
        var snapshot = ActivitySnapshot()
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }

        return snapshot
    }

    static var incompleteHistoryNotice: String {
        WalletUX.text(
            "Incoming transfers from other accounts may not appear in Activity right now. Your balances are not affected."
        )
    }

    private func contentSection(with items: [ActivitySectionItem]) -> [ActivitySection] {
        return [ActivitySection(items: items)]
    }

    /// Loads the page after the ones on screen and shows it.
    ///
    /// Everything after the wait runs on the main thread, like the calls
    /// from the screen, so the list is changed from one place at a time.
    @MainActor
    private func loadContent() async {
        let list = listNumber
        while list == listNumber, !endReached {
            let requested = pageNumber + 1
            do {
                let page = try await historyService.getPageHistory(count: 50, page: requested, assetId: assetId)
                // The list was started again, or this page already arrived,
                // while this request was on its way.
                guard list == listNumber, requested == pageNumber + 1 else { return }
                guard show(page) else { return }
                // The asset filter can leave a page empty even though
                // older pages have matches. There is no new row to scroll
                // to, so ask for the next page here.
            } catch {
                guard list == listNumber, requested == pageNumber + 1 else { return }
                guard pageNumber == 0 else {
                    if case PIIndexerError.paginationLimit = error {
                        // The list is as long as it gets.
                        endReached = true
                        view?.stopPaginationLoader()
                        return
                    }
                    // A further page could not be read and there is no saved
                    // copy of it. Offer to load the list again instead of
                    // leaving the spinner at its end.
                    showRetryRow()
                    return
                }
                showFirstPageFailure()
                return
            }
        }
    }

    /// Returns true when an accepted empty page needs the next page to
    /// be read without waiting for another scroll.
    @MainActor
    private func show(_ page: HistoryPage) -> Bool {
        let isFirstPage = pageNumber == 0
        guard isFirstPage || Self.continues(shownPages, pageCachedAt: page.cachedAt) else {
            // The page that arrived is from another moment than the
            // list on screen. Leave the list as it is and offer to
            // load it again from its start.
            showRetryRow()
            return false
        }
        removeRetryRow()
        endReached = page.endReached || pageNumber + 1 >= PIIndexerClient.maximumHistoryPages

        if isFirstPage {
            sections = []
        }

        view?.stopAnimating()

        var noticeItems: [ActivitySectionItem] = []
        if isFirstPage, let cachedAt = page.cachedAt {
            // The indexer could not be read: this is the list as it was
            // last loaded. Say when, as the wallet total does, and offer
            // to load it again. The list also asks again by itself.
            let refreshItem = ActivityErrorItem(title: WalletUX.activityAsOfText(cachedAt))
            refreshItem.handler = { [weak self] in
                self?.view?.resetPagination()
            }
            noticeItems.append(.error(refreshItem))
        }
        // The indexer could list only operations this account signed.
        // Say so calmly, so a missing incoming transfer is not taken for
        // missing funds.
        if isFirstPage && page.mayOmitIncomingTransfers {
            noticeItems.append(.notice(ActivityNoticeItem(text: Self.incompleteHistoryNotice,
                                                          roundsTop: noticeItems.isEmpty)))
        }
        let notice: [ActivitySection] = noticeItems.isEmpty ? [] : contentSection(with: noticeItems)
        shownPages = page.cachedAt.map { .saved($0) } ?? .current
        if isFirstPage {
            firstPageDidEnd(behind: page.cachedAt != nil || page.errorMessage != nil)
        }

        if isFirstPage && page.errorMessage != nil && page.transactions.isEmpty {
            sections = []
            snapshot = createSnapshot()
            setupErrorContent?()
            return false
        }

        hideErrorContent?()

        var sections: [ActivitySection] = self.viewModelFactory.createActivityViewModels(with: page.transactions) { [weak self] model in
            guard let self = self, let view = self.view else { return }
            self.wireframe.showActivityDetails(on: view.controller, model: model, assetManager: self.assetManager)
        }

        if page.errorMessage != nil {
            let errorItem = ActivityErrorItem()
            errorItem.handler = { [weak self] in
                self?.view?.resetPagination()
            }

            sections.insert(contentsOf: contentSection(with: [.error(errorItem)]), at: 0)

            let activityItemCount = self.sections.reduce(0) { partialResult, section in
                partialResult + section.items.filter { $0.isActivity }.count
            }

            let dateItemCount = self.sections.compactMap { $0.date }.count

            let tabBarSize = 30
            let visibleHeight = Int(UIScreen.main.bounds.height) - tabBarSize - (activityItemCount * 56 + dateItemCount * 32)
            let spacerItem: ActivitySectionItem = .space(SoramitsuTableViewSpacerItem(space: visibleHeight > 30 ? CGFloat(visibleHeight) : 30))
            sections.append(contentsOf: contentSection(with: [spacerItem]))
        }

        sections.insert(contentsOf: notice, at: 0)

        updateSections(with: sections)

        // Count each accepted page, even when it merged into an existing
        // day or the asset filter left no rows. Advancing before another
        // response arrives also prevents the same page being merged twice.
        reload()

        if endReached, page.errorMessage == nil,
           !self.sections.contains(where: { $0.items.contains(where: \.isActivity) }) {
            setupEmptyLabel?()
        }
        return page.transactions.isEmpty && page.errorMessage == nil && !endReached
    }

    /// Page 1 could not be loaded and there is no saved copy to show: the
    /// "Could not load your activity" text with its Refresh button, and
    /// nothing under it. The list asks again by itself.
    @MainActor
    private func showFirstPageFailure() {
        sections = []
        retryRow = nil
        shownPages = .none
        snapshot = createSnapshot()
        view?.stopAnimating()
        view?.stopPaginationLoader()
        setupErrorContent?()
        firstPageDidEnd(behind: true)
    }

    /// One row at the end of the list: "Some data is not up to date" with
    /// a Refresh button, which loads the list again from its start.
    private func showRetryRow() {
        view?.stopPaginationLoader()
        guard retryRow == nil else { return }
        let errorItem = ActivityErrorItem(roundsTop: false)
        errorItem.handler = { [weak self] in
            self?.view?.resetPagination()
        }
        let row = ActivitySection(items: [.error(errorItem)])
        retryRow = row
        sections.append(row)
        snapshot = createSnapshot()
    }

    private func removeRetryRow() {
        guard let row = retryRow else { return }
        retryRow = nil
        sections.removeAll { $0 === row }
    }

    // MARK: - A list that is behind asks again by itself

    /// A load of page 1 ended.
    private func firstPageDidEnd(behind: Bool) {
        firstPageEndedAt = uptime()
        isBehind = behind
        if behind {
            scheduleRefresh()
        } else {
            refreshFailures = 0
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    /// Waits `refreshDelay`, then asks for page 1 again.
    private func scheduleRefresh() {
        guard isBehind, !isRefreshing, refreshTask == nil else { return }
        let delay = min(max(0, refreshDelay(refreshFailures)), 3_600)
        refreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.refreshFirstPage()
        }
    }

    /// Asks for page 1 again without waiting: the app came to the
    /// foreground, or the screen is shown again.
    private func refreshNowIfBehind(startingOver: Bool) {
        guard isBehind else { return }
        if startingOver {
            refreshFailures = 0
        }
        // Page 1 is being asked for at this moment: its answer will do.
        guard !isRefreshing else { return }
        if !startingOver,
           let endedAt = firstPageEndedAt,
           uptime() - endedAt < Self.minimumRefreshSpacing {
            return
        }
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            await self?.refreshFirstPage()
        }
    }

    /// Reads page 1 behind the list on screen. The list is replaced only
    /// when the page is a current one; a failed read, or the saved copy
    /// again, leaves the screen as it is and the next try is scheduled.
    @MainActor
    private func refreshFirstPage() async {
        guard isBehind, !isRefreshing, !Task.isCancelled else { return }
        isRefreshing = true
        let list = listNumber
        let page = try? await historyService.getPageHistory(count: 50, page: 1, assetId: assetId)
        isRefreshing = false
        refreshTask = nil
        firstPageEndedAt = uptime()
        // Loaded again by the user, or by a new transaction, meanwhile:
        // that load decides what is shown.
        guard isBehind else { return }
        guard list == listNumber else {
            scheduleRefresh()
            return
        }
        if let page, page.cachedAt == nil, page.errorMessage == nil {
            startList()
            if show(page) {
                await loadContent()
            }
            return
        }
        refreshFailures += 1
        if let page, shownPages == .none {
            // Nothing is on screen but the "could not load" text, and a
            // saved copy can be read now: show it, and keep asking.
            startList()
            if show(page) {
                await loadContent()
            }
            return
        }
        scheduleRefresh()
    }

    /// Forgets the list on screen: the next page shown is page 1.
    private func startList() {
        listNumber += 1
        viewModelFactory.currentDate = nil
        pageNumber = 0
        sections = []
        retryRow = nil
        endReached = false
        shownPages = .none
    }

    private func updateSections(with sections: [ActivitySection]) {
        sections.forEach { [weak self] section in
            guard let date = section.date else {
                self?.sections.append(section)
                return
            }

            if let index = self?.sections.firstIndex(where: { $0.date == date }) {
                self?.sections[index].items.append(contentsOf: section.items)
                return
            }

            self?.sections.append(section)
        }
    }

    func didSelect(with item: ActivitySectionItem) {
        switch item {
        case .activity(let activityItem):
            activityItem.handler?()
        case .error(let errorItem):
            errorItem.handler?()
        default:
            return
        }
    }

    func headerText(for section: Int) -> String? {
        guard sections.count > section, let date = sections[section].date else { return nil }
        return date.uppercased()
    }

    func isNeedHeader(for section: Int) -> Bool {
        guard sections.count > section else { return false }
        return sections[section].date != nil
    }

    func resetPagination() {
        startList()
        // This load decides whether the list is behind; nothing asks for
        // page 1 next to it.
        isBehind = false
        refreshTask?.cancel()
        refreshTask = nil

        task?.cancel()
        task = Task { [weak self] in
            await self?.loadContent()
        }
    }

    func viewWillAppear() {
        refreshNowIfBehind(startingOver: false)
    }
}

extension ActivityViewModel: EventVisitorProtocol {

    func processNewTransactionCreated(event: NewTransactionCreatedEvent) {
        DispatchQueue.main.async {
            self.view?.resetPagination()
        }
    }

    func processNewTransaction(event: WalletNewTransactionInserted) {
        DispatchQueue.main.async {
            self.view?.resetPagination()
        }
    }

    /// A sent transaction received its final status: show it.
    func processPendingSubmissionsResolved(event _: Sora2PendingSubmissionsResolved) {
        DispatchQueue.main.async {
            self.view?.resetPagination()
        }
    }
}

extension ActivityViewModel: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        self.view?.resetPagination()
    }
}
