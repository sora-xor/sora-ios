// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import Combine
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class PoolCellLifecycleTests: XCTestCase {
    private var language = "en"
    override func setUp() { super.setUp(); language = LocalizationManager.shared.selectedLocalization; LocalizationManager.shared.selectedLocalization = "en" }
    override func tearDown() { LocalizationManager.shared.selectedLocalization = language; super.tearDown() }
    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) }
    }
    private func settle() async { try? await Task.sleep(nanoseconds: 50_000_000) }
    private func row(_ id: String = "pool", fiat: String = "$10") -> PoolViewModel {
        PoolViewModel(identifier: id, title: "XOR-VAL \(id)", subtitle: "1 XOR - 2 VAL", fiatText: fiat,
                      baseAssetImage: UIImage(systemName: "circle"), targetAssetImage: UIImage(systemName: "square"),
                      rewardAssetImage: UIImage(systemName: "star"), farmedRewardAssetsImages: [UIImage(systemName: "leaf")!])
    }
    private func service(rows: [PoolViewModel]) -> PoolsItemService {
        let manager = PoolCellAssets()
        let service = PoolsItemService(marketCapService: PoolCellMarket(), fiatService: nil,
            poolViewModelsFactory: PoolViewModelFactory(walletAssets: [], assetManager: manager, fiatService: nil))
        service.poolViewModels = rows
        service.moneyText = "$10"
        return service
    }
    func testEmptyPoolListCanLaterDisplayItsFirstPool() async {
        let service = service(rows: [])
        let cell = PoolsCell(style: .default, reuseIdentifier: nil)
        let item = PoolsItem(title: "Pools", service: service)
        cell.set(item: item, context: nil); await settle()
        XCTAssertTrue(views(MainScreenPoolView.self, in: cell).isEmpty)
        service.poolViewModels = [row()]; await settle()
        XCTAssertEqual(views(MainScreenPoolView.self, in: cell).count, 1)
        let container = views(MainScreenPoolView.self, in: cell).first?.superview?.superview
        let collapsed = (container?.constraints ?? []).filter {
            $0.isActive && $0.firstItem === container && $0.firstAttribute == .height && $0.secondItem == nil && $0.constant == 0
        }
        XCTAssertTrue(collapsed.isEmpty, "Loaded pool container must not retain the empty-state zero-height constraint")
    }
    func testRebindingPoolCellUsesOnlyTheNewService() async {
        let old = service(rows: [row("old")]); let current = service(rows: [row("current")])
        let cell = PoolsCell(style: .default, reuseIdentifier: nil)
        let first = PoolsItem(title: "Old", service: old); let second = PoolsItem(title: "Current", service: current)
        cell.set(item: first, context: nil); await settle()
        cell.set(item: second, context: nil); await settle()
        old.poolViewModels = [row("obsolete")]; old.moneyText = "$99"; await settle()
        XCTAssertEqual(views(MainScreenPoolView.self, in: cell).first?.titleLabel.text, "XOR-VAL current")
        XCTAssertFalse(views(UILabel.self, in: cell).contains { $0.text == "$99" })
        current.poolViewModels = [row("updated")]; await settle()
        XCTAssertEqual(views(MainScreenPoolView.self, in: cell).first?.titleLabel.text, "XOR-VAL updated")
    }
    func testRebindingPoolCellUsesTheCurrentHandlers() async throws {
        let service = service(rows: [row()])
        let first = PoolsItem(title: "Old", service: service); let second = PoolsItem(title: "Current", service: service)
        var obsolete = 0; var current = 0; var ids: [String] = []
        first.arrowButtonHandler = { obsolete += 1 }; first.poolHandler = { _ in obsolete += 1 }
        second.arrowButtonHandler = { current += 1 }; second.poolHandler = { ids.append($0) }
        let cell = PoolsCell(style: .default, reuseIdentifier: nil)
        cell.set(item: first, context: nil); await settle()
        cell.set(item: second, context: nil); await settle()
        try XCTUnwrap(views(WalletHeaderView.self, in: cell).first).sendActions(for: .touchUpInside)
        try XCTUnwrap(views(MainScreenPoolView.self, in: cell).first).sendActions(for: .touchUpInside)
        XCTAssertEqual(obsolete, 0)
        XCTAssertEqual(current, 1)
        XCTAssertEqual(ids, ["pool"])
    }
    func testCollapsedPoolRowsAndExpandActionFollowCurrentState() async throws {
        let service = service(rows: [row(), row("two")])
        let item = PoolsItem(title: "Pools", isExpand: false, service: service)
        var expanded = 0; item.expandButtonHandler = { expanded += 1 }
        let cell = PoolsCell(style: .default, reuseIdentifier: nil)
        cell.set(item: item, context: nil); await settle()
        XCTAssertTrue(views(MainScreenPoolView.self, in: cell).allSatisfy(\.isHidden))
        item.isExpand = true; cell.set(item: item, context: nil)
        XCTAssertTrue(views(MainScreenPoolView.self, in: cell).allSatisfy { !$0.isHidden })
        let button = try XCTUnwrap(views(SoramitsuButton.self, in: cell).first)
        XCTAssertFalse(button.isHidden)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(expanded, 1)
    }
    func testFinishedUnknownPoolPriceClearsThePreviouslyDisplayedValue() async throws {
        let service = service(rows: [row()]); let item = PoolsItem(title: "Pools", service: service)
        let cell = PoolsCell(style: .default, reuseIdentifier: nil)
        cell.set(item: item, context: nil); await settle()
        var unavailable = row(fiat: ""); unavailable.priceLoadFinished = true
        service.poolViewModels = [unavailable]; await settle()
        let pool = try XCTUnwrap(views(MainScreenPoolView.self, in: cell).first)
        XCTAssertEqual(pool.amountUpLabel.text, "")
        XCTAssertEqual(pool.amountUpLabel.sora.loadingPlaceholder.type, .none)
    }
    private func detail(_ name: String, progress: Bool = false) -> DetailViewModel {
        DetailViewModel(title: name, assetAmountText: SoramitsuTextItem(text: "10 XOR", fontData: FontType.textS),
                        fiatAmountText: SoramitsuTextItem(text: "$20", fontData: FontType.textS), type: progress ? .progress(0.5) : .casual)
    }
    private func item(service: PoolCellDetails? = nil, available: Bool = true, liquidity: Bool = true,
                      details: [DetailViewModel] = []) -> PoolDetailsItem {
        PoolDetailsItem(title: "XOR-VAL", firstAssetImage: nil, secondAssetImage: nil, rewardAssetImage: nil,
            isRemoveLiquidityEnabled: available, typeImage: .activePoolWithFarming, isThereLiquidity: liquidity,
            detailsViewModels: details, poolInfo: PoolInfo(baseAssetId: "xor", targetAssetId: "val", poolId: "pool", accountId: ""), service: service)
    }
    func testPoolDetailsRenderProgressAndInfoAndReplaceOldRows() throws {
        let cell = PoolDetailsCell(style: .default, reuseIdentifier: nil)
        let first = detail("Share", progress: true); let second = detail("Reward")
        var calls = 0; first.infoHandler = { calls += 1 }
        cell.set(item: item(details: [first, second]))
        let rows = views(DetailView.self, in: cell)
        XCTAssertEqual(rows.count, 2)
        XCTAssertFalse(rows[0].progressView.isHidden)
        XCTAssertTrue(rows[1].progressView.isHidden)
        rows[0].infoButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 1)
        cell.set(item: item(details: [second]))
        XCTAssertEqual(views(DetailView.self, in: cell).count, 1)
        XCTAssertEqual(views(DetailView.self, in: cell).first?.titleLabel.text, "Reward")
    }
    func testPoolDetailsDisablesRemovalUntilLiquidityIsUnstaked() throws {
        let cell = PoolDetailsCell(style: .default, reuseIdentifier: nil)
        cell.set(item: item(available: false))
        XCTAssertFalse(cell.limitationLabel.isHidden)
        XCTAssertEqual(views(SoramitsuButton.self, in: cell).filter { !$0.isEnabled }.count, 1)
        cell.set(item: item(available: true, liquidity: false))
        XCTAssertTrue(cell.limitationLabel.isHidden)
        XCTAssertEqual(views(SoramitsuButton.self, in: cell).filter { !$0.isEnabled }.count, 1)
        let current = item(); var actions: [Liquidity.TransactionLiquidityType] = []
        current.handler = { actions.append($0) }; cell.set(item: current)
        views(SoramitsuButton.self, in: cell).forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertEqual(actions, [.add, .withdraw])
        XCTAssertTrue(views(SoramitsuButton.self, in: cell).allSatisfy(\.isEnabled))
    }
    func testPoolDetailsRebindingCancelsTheOldValueAndDetailsPublishers() async {
        let old = PoolCellDetails(); let current = PoolCellDetails()
        let first = item(service: old, details: [detail("Old")]); let second = item(service: current, details: [detail("Current")])
        let cell = PoolDetailsCell(style: .default, reuseIdentifier: nil)
        cell.set(item: first); await settle()
        cell.set(item: second); await settle()
        current.tvl = "$20 TVL"; current.details = [detail("New")]; await settle()
        old.tvl = "$99 TVL"; old.details = [detail("Obsolete")]; await settle()
        XCTAssertEqual(views(DetailView.self, in: cell).first?.titleLabel.text, "New")
        XCTAssertTrue(views(UILabel.self, in: cell).contains { $0.text == "$20 TVL" })
        XCTAssertFalse(views(UILabel.self, in: cell).contains { $0.text == "$99 TVL" })
        current.unavailable = true; await settle()
        XCTAssertFalse(views(UILabel.self, in: cell).contains { $0.text == "$20 TVL" })
    }
    func testPoolDetailsIdentityIncludesDisplayedAndActionState() {
        let original = item(details: [detail("Old")])
        XCTAssertNotEqual(original, item(available: false, details: [detail("Old")]))
        XCTAssertNotEqual(original, item(details: [detail("Changed")]))
        let changedTitle = item(details: [detail("Old")]); changedTitle.title = "XOR-PSWAP"
        XCTAssertNotEqual(original, changedTitle)
        XCTAssertEqual(original, item(details: [detail("Old")]))
    }
}
private final class PoolCellDetails: PoolDetailsItemServiceProtocol {
    @Published var tvl = ""
    @Published var unavailable = false
    @Published var details: [DetailViewModel] = []
    var tvlTextPublisher: Published<String>.Publisher { $tvl }
    var tvlUnavailablePublisher: Published<Bool>.Publisher { $unavailable }
    var detailsPublisher: Published<[DetailViewModel]>.Publisher { $details }
    func setup(with poolInfo: PoolInfo) {}
}
private final class PoolCellAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    func assetInfo(for identifier: String) -> AssetInfo? { nil }
    func getAssetList() -> [AssetInfo]? { [] }
    func updateAssetList(_ list: [AssetInfo]) {}
    func saveAssetList(_ list: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { 0 }
    func setup(for accountSettings: SelectedWalletSettings) {}
}
private final class PoolCellMarket: MarketCapServiceProtocol {
    func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] }
}
