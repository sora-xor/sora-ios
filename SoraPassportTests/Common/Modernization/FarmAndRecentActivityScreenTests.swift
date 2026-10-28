// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import Combine
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class FarmAndRecentActivityScreenTests: XCTestCase {
    private var subscriptions = Set<AnyCancellable>()
    override func tearDown() { subscriptions.removeAll(); super.tearDown() }
    private func pause() async { try? await Task.sleep(nanoseconds: 35_000_000) }
    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) }
    }
    private func farm(_ id: String = "farm", title: String = "XOR-VAL", subtitle: String = "Reward PSWAP", apr: String? = "10%", percentage: String? = "20%", active: Bool = false, image: UIImage? = nil) -> FarmViewModel {
        FarmViewModel(identifier: id, title: title, subtitle: subtitle, baseAssetImage: image, targetAssetImage: image, rewardAssetImage: image, aprText: apr, percentageText: percentage, isFarmed: active)
    }
    func testFarmListShowsBothStatesWithCorrectAmountsAndAPR() {
        let cell = FarmListCell(style: .default, reuseIdentifier: nil)
        cell.set(item: FarmListItem(title: "Farms", farmViewModels: [farm("idle"), farm("active", active: true)]))
        let rows = views(FarmView.self, in: cell); XCTAssertEqual(rows.count, 2); XCTAssertEqual(cell.titleLabel.text, "Farms")
        XCTAssertEqual(rows[0].roundedAprLabel.text, "10%"); XCTAssertFalse(rows[0].roundedAprLabel.isHidden); XCTAssertTrue(rows[0].secondaryInfoStackView.isHidden)
        XCTAssertTrue(rows[1].roundedAprLabel.isHidden); XCTAssertFalse(rows[1].secondaryInfoStackView.isHidden); XCTAssertEqual(rows[1].poolPercentageLabel.text, "20%")
    }
    func testFarmListUpdatesAndClearsRowsWithoutAccumulatingViews() {
        let cell = FarmListCell(style: .default, reuseIdentifier: nil)
        cell.set(item: FarmListItem(title: "Old", farmViewModels: [farm("one"), farm("two")]))
        cell.set(item: FarmListItem(title: "New", farmViewModels: [farm("three", title: "Current")]))
        XCTAssertEqual(views(FarmView.self, in: cell).map { $0.titleLabel.text }, ["Current"])
        cell.set(item: FarmListItem(title: "Empty", farmViewModels: [])); XCTAssertTrue(views(FarmView.self, in: cell).isEmpty)
    }
    func testFarmListRoutesOnlyTheCurrentFarmAndHandler() throws {
        let cell = FarmListCell(style: .default, reuseIdentifier: nil); var old: [String] = []; var current: [String] = []
        cell.set(item: FarmListItem(title: "Old", farmViewModels: [farm("old")], tapHandler: { old.append($0) }))
        cell.set(item: FarmListItem(title: "Current", farmViewModels: [farm("current")], tapHandler: { current.append($0) }))
        try XCTUnwrap(views(FarmView.self, in: cell).first).sendActions(for: .touchUpInside)
        XCTAssertTrue(old.isEmpty); XCTAssertEqual(current, ["current"])
    }
    func testFarmMissingDataShimmersAndPopulatedImagesStopLoading() throws {
        let cell = FarmListCell(style: .default, reuseIdentifier: nil)
        cell.set(item: FarmListItem(title: "Pending", farmViewModels: [farm(apr: nil, percentage: nil)]))
        let pending = try XCTUnwrap(views(FarmView.self, in: cell).first)
        XCTAssertEqual(pending.roundedAprLabel.sora.loadingPlaceholder.type, .shimmer)
        let image = UIImage(systemName: "circle")!
        cell.set(item: FarmListItem(title: "Ready", farmViewModels: [farm(image: image)]))
        let loaded = try XCTUnwrap(views(FarmView.self, in: cell).first)
        XCTAssertEqual(loaded.firstCurrencyImageView.sora.loadingPlaceholder.type, .none)
        XCTAssertEqual(loaded.secondCurrencyImageView.sora.loadingPlaceholder.type, .none)
        XCTAssertEqual(loaded.rewardImageView.sora.loadingPlaceholder.type, .none)
        XCTAssertEqual(loaded.roundedAprLabel.sora.loadingPlaceholder.type, .none)
    }
    func testFarmIdentityIncludesTheStakedState() { XCTAssertNotEqual(farm(), farm(active: true)) }
    func testFarmIdentityIncludesTheDisplayedShare() { XCTAssertNotEqual(farm(), farm(percentage: "30%")) }
    func testFarmIdentityIncludesTheDisplayedNameAndReward() { XCTAssertNotEqual(farm(), farm(title: "XOR-PSWAP")); XCTAssertNotEqual(farm(), farm(subtitle: "Reward VAL")) }
    func testFarmIdentityIncludesLoadedImagesAndSupportsEqualValues() {
        let image = UIImage(systemName: "circle")!; XCTAssertNotEqual(farm(), farm(image: image)); XCTAssertEqual(farm(), farm()); XCTAssertEqual(Set([farm(), farm()]).count, 1)
    }
    func testFarmListIdentityPropagatesChangesToDisplayedRows() {
        XCTAssertNotEqual(FarmListItem(title: "Farms", farmViewModels: [farm()]), FarmListItem(title: "Farms", farmViewModels: [farm(active: true)]))
    }
    func testFarmViewUsesTheCurrentLanguageDirection() {
        let previous = LocalizationManager.shared.selectedLocalization; defer { LocalizationManager.shared.selectedLocalization = previous }
        LocalizationManager.shared.selectedLocalization = "ar"; let view = FarmView(); XCTAssertEqual(view.titleLabel.sora.alignment, .right)
        LocalizationManager.shared.selectedLocalization = "en"; let leftToRight = FarmView(); XCTAssertEqual(leftToRight.titleLabel.sora.alignment, .left)
    }
    private func row(_ hash: String, twoImages: Bool = false, status: TransactionBase.Status = .success) -> ActivityContentViewModel {
        ActivityContentViewModel(txHash: hash, title: hash, subtitle: "Today", typeTransactionImage: UIImage(systemName: "arrow.up"),
            firstAssetImageViewModel: UIImage(systemName: "circle"), secondAssetImageViewModel: UIImage(systemName: "square"),
            firstBalanceText: SoramitsuTextItem(text: "12 XOR", fontData: FontType.textM), status: status, isNeedTwoImage: twoImages)
    }
    private func service() -> (RecentActivityItemService, RecentScreenHistory, RecentScreenEvents, RecentScreenAssets) {
        let history = RecentScreenHistory(); let events = RecentScreenEvents(); let assets = RecentScreenAssets()
        return (RecentActivityItemService(assetId: "asset", viewModelFactory: RecentScreenFactory(), historyService: history, eventCenter: events, assetsProvider: assets), history, events, assets)
    }
    private func itemAndService(_ rows: [ActivityContentViewModel]) async -> (RecentActivityItem, RecentActivityItemService) {
        let (source, _, _, _) = service(); let item = RecentActivityItem(service: source); await pause(); source.historyViewModels = rows; return (item, source)
    }
    func testRecentActivityRendersOneAndTwoAssetRowsAndPendingStatus() async throws {
        let (item, source) = await itemAndService([row("one"), row("two", twoImages: true, status: .pending)])
        let cell = RecentActivityCell(style: .default, reuseIdentifier: nil); cell.set(item: item, context: nil); await pause()
        let rows = views(ActivityView.self, in: cell); XCTAssertEqual(rows.map { $0.titleLabel.text }, ["one", "two"])
        XCTAssertTrue(rows[0].secondCurrencyImageView.isHidden); XCTAssertFalse(rows[1].secondCurrencyImageView.isHidden)
        XCTAssertEqual(rows[1].amountUpLabel.attributedText?.string, "12 XOR"); XCTAssertFalse(rows[1].statusImageView.isHidden)
        withExtendedLifetime(source) {}
    }
    func testRecentActivityRebindingDisconnectsTheOldService() async {
        let (old, oldSource) = await itemAndService([row("old")]); let (current, currentSource) = await itemAndService([row("current")])
        let cell = RecentActivityCell(style: .default, reuseIdentifier: nil); cell.set(item: old, context: nil); await pause(); cell.set(item: current, context: nil); await pause()
        oldSource.historyViewModels = [row("stale")]; await pause(); XCTAssertEqual(views(ActivityView.self, in: cell).first?.titleLabel.text, "current")
        currentSource.historyViewModels = [row("updated")]; await pause(); XCTAssertEqual(views(ActivityView.self, in: cell).first?.titleLabel.text, "updated")
    }
    func testRecentActivityRebindingUsesOnlyTheCurrentNavigationActions() async throws {
        let (old, oldSource) = await itemAndService([row("old")]); let (current, currentSource) = await itemAndService([row("current")])
        var oldCalls = 0; var hashes: [String] = []; var full = 0; old.openActivityDetailsHandler = { _ in oldCalls += 1 }; old.openFullActivityHandler = { oldCalls += 1 }
        current.openActivityDetailsHandler = { hashes.append($0) }; current.openFullActivityHandler = { full += 1 }
        let cell = RecentActivityCell(style: .default, reuseIdentifier: nil); cell.set(item: old, context: nil); await pause(); cell.set(item: current, context: nil); await pause()
        try XCTUnwrap(views(ActivityView.self, in: cell).first).sendActions(for: .touchUpInside); try XCTUnwrap(views(SoramitsuButton.self, in: cell).first).sendActions(for: .touchUpInside)
        XCTAssertEqual(oldCalls, 0); XCTAssertEqual(hashes, ["current"]); XCTAssertEqual(full, 1); withExtendedLifetime((oldSource, currentSource)) {}
    }
    func testRecentActivityCanRecoverFromAnEmptyList() async {
        let (item, source) = await itemAndService([]); let cell = RecentActivityCell(style: .default, reuseIdentifier: nil); cell.set(item: item, context: nil); await pause()
        source.historyViewModels = [row("loaded")]; await pause(); XCTAssertEqual(views(ActivityView.self, in: cell).count, 1)
        let container = views(ActivityView.self, in: cell).first?.superview?.superview
        XCTAssertFalse((container?.constraints ?? []).contains { $0.isActive && $0.firstItem === container && $0.firstAttribute == .height && $0.secondItem == nil && $0.constant == 0 })
    }
    func testRecentHistoryRequestsTheCurrentAssetAndOnlyDisplaysThreeRows() async {
        let (source, history, _, _) = service(); history.transactions = (1...5).map { recentTransaction("tx\($0)") }
        source.setup(); await pause(); XCTAssertEqual(history.requests.map(\.0), [100]); XCTAssertEqual(history.requests.map(\.1), ["asset"])
        XCTAssertEqual(source.historyViewModels.map(\.txHash), ["tx1", "tx2", "tx3"])
    }
    func testRecentHistoryCompletionPublishesOnTheMainThread() async {
        let (source, history, _, _) = service(); history.transactions = [recentTransaction("loaded")]
        let published = expectation(description: "main publication")
        source.$historyViewModels.dropFirst().sink { _ in XCTAssertTrue(Thread.isMainThread); published.fulfill() }.store(in: &subscriptions)
        source.setup(); await fulfillment(of: [published], timeout: 2)
    }
    func testRecentHistoryFailureClearsOldRowsAndNotifiesOnce() async {
        let (source, history, _, _) = service(); source.historyViewModels = [row("old")]; history.failure = URLError(.notConnectedToInternet)
        let published = expectation(description: "error publication"); source.updateHandler = { published.fulfill() }; source.setup(); await fulfillment(of: [published], timeout: 2)
        XCTAssertTrue(source.historyViewModels.isEmpty)
    }
    func testRecentHistoryOlderCompletionCannotReplaceTheLatestRefresh() async {
        let (source, history, _, _) = service(); history.suspends = true
        source.setup(); await pause(); source.setup(); await pause(); XCTAssertEqual(history.pendingCount, 2)
        history.complete(1, transactions: [recentTransaction("new")]); await pause()
        history.complete(0, transactions: [recentTransaction("old")]); await pause()
        XCTAssertEqual(source.historyViewModels.map(\.txHash), ["new"])
    }
    func testRecentHistoryReleasesEventAndBalanceObserversWhenDiscarded() async {
        var source: RecentActivityItemService?; let history = RecentScreenHistory(); let events = RecentScreenEvents(); let assets = RecentScreenAssets()
        source = RecentActivityItemService(assetId: "asset", viewModelFactory: RecentScreenFactory(), historyService: history, eventCenter: events, assetsProvider: assets)
        XCTAssertNotNil(source); XCTAssertEqual(events.adds, 1); XCTAssertEqual(assets.adds, 1); source = nil; await pause()
        XCTAssertEqual(events.removes, 1); XCTAssertEqual(assets.removes, 1)
    }
    func testRecentHistoryBalanceAndResolvedEventsRefreshWithoutNetworkSideEffects() async {
        let (source, history, _, _) = service(); source.processBalance(data: []); await pause(); source.processPendingSubmissionsResolved(event: Sora2PendingSubmissionsResolved()); await pause()
        XCTAssertEqual(history.requests.count, 2)
    }
}
private func recentTransaction(_ hash: String) -> Transaction {
    TransferTransaction(base: TransactionBase(txHash: hash, blockHash: "block", fee: Amount(value: 0), status: .success, timestamp: "1700000000"), amount: Amount(value: 1), peer: "peer", transferType: .incoming, tokenId: "asset")
}
private final class RecentScreenHistory: HistoryServiceProtocol {
    var transactions: [Transaction] = []; var failure: Error?; var suspends = false
    private let lock = NSLock(); private var pending: [CheckedContinuation<[Transaction], Error>?] = []; private var recorded: [(Int, String?)] = []
    var requests: [(Int, String?)] { lock.lock(); defer { lock.unlock() }; return recorded }
    var pendingCount: Int { lock.lock(); defer { lock.unlock() }; return pending.count }
    func complete(_ index: Int, transactions: [Transaction]) { lock.lock(); let continuation = pending[index]; pending[index] = nil; lock.unlock(); continuation?.resume(returning: transactions) }
    func getHistory(count: Int, assetId: String?) async throws -> [Transaction] {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock(); recorded.append((count, assetId)); if suspends { pending.append(continuation); lock.unlock() } else { lock.unlock(); if let failure { continuation.resume(throwing: failure) } else { continuation.resume(returning: transactions) } }
        }
    }
    func getHistory(count: Int, assetId: String?, completion: @escaping (Result<[Transaction], Error>) -> Void) { completion(.success(transactions)) }
    func getPageHistory(count: Int, page: Int, assetId: String?, completion: @escaping (Result<HistoryPage, Error>) -> Void) { XCTFail("Unexpected page request") }
    func getTransaction(by txHash: String) -> Transaction? { nil }
    func getPageHistory(count: Int, page: Int, assetId: String?) async throws -> HistoryPage { throw CancellationError() }
}
private final class RecentScreenFactory: ActivityViewModelFactoryProtocol {
    var currentDate: Date?
    func createActivityViewModels(with transactions: [Transaction], tapHandler: @escaping (Transaction) -> Void) -> [ActivitySection] { [] }
    func createActivityShimmerModels() -> [ActivitySection] { [] }
    func createActivityViewModel(with transaction: Transaction) -> ActivityContentViewModel? { ActivityContentViewModel(txHash: transaction.base.txHash, title: transaction.base.txHash) }
}
private final class RecentScreenEvents: EventCenterProtocol {
    var adds = 0; var removes = 0
    func notify(with event: EventProtocol) {}; func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) { completionOnMain() }
    func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) { adds += 1 }; func remove(observer: EventVisitorProtocol) { removes += 1 }
}
private final class RecentScreenAssets: AssetProviderProtocol {
    var adds = 0; var removes = 0
    func getBalances(with assetIds: [String]) -> [BalanceData] { [] }; func add(observer: AssetProviderObserverProtocol) { adds += 1 }; func remove(observer: AssetProviderObserverProtocol) { removes += 1 }
}
