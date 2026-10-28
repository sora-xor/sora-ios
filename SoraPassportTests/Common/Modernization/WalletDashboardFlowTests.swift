// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import Combine
import IrohaCrypto
import RobinHood
import SoraKeystore
import SoraFoundation
import SoraUIKit
import SSFUtils
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class WalletDashboardFlowTests: XCTestCase {
    private var previousAccount: AccountItem?
    private var settings: [String: Any] = [:]
    private var priorNexus = false
    private var owner: AccountItem!
    private let keys = ["enabledCardIdentifiers", "backupedAccountAddresses", "savedAddresses"]
    override func setUpWithError() throws {
        try super.setUpWithError()
        previousAccount = SelectedWalletSettings.shared.currentAccount
        for key in keys { if let value = UserDefaults.standard.object(forKey: key) { settings[key] = value }; UserDefaults.standard.removeObject(forKey: key) }
        priorNexus = SettingsManager.shared.nexusEnabled; SettingsManager.shared.nexusEnabled = false
        let publicKey = Data(repeating: 7, count: 32)
        owner = AccountItem(address: try SS58AddressFactory().address(fromAccountId: publicKey, type: SNAddressType(chain: .sora)), cryptoType: .sr25519, networkType: 69, username: "Dashboard fixture", publicKeyData: publicKey, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        SelectedWalletSettings.shared.commitInternalValue(owner)
    }
    override func tearDown() {
        for key in keys { UserDefaults.standard.set(settings[key], forKey: key) }
        SettingsManager.shared.nexusEnabled = priorNexus
        SelectedWalletSettings.shared.commitInternalValue(previousAccount)
        super.tearDown()
    }
    private struct Fixture { let model: RedesignWalletViewModel; let route: DashboardRoute; let view: DashboardView; let edit: DashboardEdit; let pools: DashboardPools; let source: DashboardSource }
    private func make() -> Fixture {
        let assets = DashboardAssets(), fiat = DashboardFiat(), market = DashboardMarket(), pools = DashboardPools(), network = WalletNetworkOperationFactoryProtocolMock(), edit = DashboardEdit(), route = DashboardRoute(), view = DashboardView(), source = DashboardSource()
        let poolRows = PoolsItemService(marketCapService: market, fiatService: fiat, poolViewModelsFactory: PoolViewModelFactory(walletAssets: assets.assets, assetManager: assets, fiatService: fiat))
        let model = RedesignWalletViewModel(wireframe: route, providerFactory: BalanceProviderFactory(accountId: owner.address, cacheFacade: CoreDataCacheFacade.shared, networkOperationFactory: network, identifierFactory: SingleProviderIdentifierFactory()), assetManager: assets, fiatService: fiat, farmingService: DashboardFarms(), itemFactory: WalletItemFactory(), networkFacade: network, accountId: owner.publicKeyData.toHex(), address: owner.address, polkaswapNetworkFacade: PolkaswapNetworkOperationFactory(engine: DashboardEngine()), qrEncoder: DashboardQR(), sharingFactory: DashboardShare(), poolsService: pools, referralFactory: DashboardReferrals(), assetsProvider: DashboardBalances(), walletContext: WalletContextMock(), editViewService: edit, poolsViewModelService: poolRows, marketCapService: market)
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        model.portfolioHome = PortfolioHome(dataSource: source, preferences: PortfolioPreferences(defaults: suite))
        model.view = view
        return Fixture(model: model, route: route, view: view, edit: edit, pools: pools, source: source)
    }
    private func load(_ f: Fixture) { f.model.fetchAssets { _ in } }
    private func row<T>(_ type: T.Type, _ f: Fixture) throws -> T { try XCTUnwrap(f.model.walletItems.compactMap { $0 as? T }.first) }
    private func displayed(_ f: Fixture) -> [SoramitsuTableViewItemProtocol] { var rows: [SoramitsuTableViewItemProtocol] = []; f.model.setupItems = { rows = $0 }; f.model.updateItems(); return rows }
    private func wait() async { try? await Task.sleep(nanoseconds: 30_000_000) }

    func testInitialCardsContainBackupReferralPoolsAndEditing() throws { let f = make(); load(f); XCTAssertEqual(f.model.walletItems.count, 4); _ = try row(BackupItem.self, f); _ = try row(FriendsItem.self, f); _ = try row(PoolsItem.self, f); _ = try row(EditViewItem.self, f) }
    func testFetchCompletionReturnsTheSameRenderedCardsExactlyOnce() { let f = make(); var renders = 0, completions = 0; var shown: [SoramitsuTableViewItemProtocol] = []; f.model.setupItems = { renders += 1; shown = $0 }; f.model.fetchAssets { rows in completions += 1; XCTAssertEqual(rows.map { ObjectIdentifier($0) }, shown.map { ObjectIdentifier($0) }) }; XCTAssertEqual(renders, 1); XCTAssertEqual(completions, 1) }
    func testRebuildingCardsDoesNotAppendDuplicates() { let f = make(); load(f); load(f); XCTAssertEqual(f.model.walletItems.count, 4); XCTAssertEqual(displayed(f).filter { $0 is BackupItem }.count, 1) }
    func testUnknownBackupStateShowsTheBackupCard() { let f = make(); load(f); XCTAssertTrue(displayed(f).contains { $0 is BackupItem }) }
    func testCloudBackupHidesOnlyThisAccountsBackupCard() { let f = make(); load(f); ApplicationConfig.shared.backupedAccountAddresses = [owner.address]; XCTAssertFalse(displayed(f).contains { $0 is BackupItem }) }
    func testAnotherWalletsBackupDoesNotHideThisWalletsCard() { let f = make(); load(f); ApplicationConfig.shared.backupedAccountAddresses = ["another-wallet"]; XCTAssertTrue(displayed(f).contains { $0 is BackupItem }) }
    func testLocallyConfirmedBackupAlsoHidesTheCard() { let f = make(); load(f); UserDefaults.standard.set([owner.address], forKey: "savedAddresses"); XCTAssertFalse(displayed(f).contains { $0 is BackupItem }) }
    func testClosingReferralPreservesPoolPreferenceAndUpdatesVisibility() throws { let f = make(); load(f); try row(FriendsItem.self, f).onClose?(); XCTAssertEqual(ApplicationConfig.shared.getAvailableApplicationSections(), [Cards.pooledAssets.id]); XCTAssertTrue(f.model.isReferralProgramHidden); XCTAssertFalse(displayed(f).contains { $0 is FriendsItem }) }
    func testDisabledPoolsAreRemovedAndMarkedHidden() throws { let f = make(); load(f); ApplicationConfig.shared.updateAvailableApplicationSections(cards: [Cards.referralProgram.id]); XCTAssertFalse(displayed(f).contains { $0 is PoolsItem }); XCTAssertTrue(try row(PoolsItem.self, f).isHidden) }
    func testReenabledPoolsReappearWithoutRebuilding() throws { let f = make(); load(f); ApplicationConfig.shared.updateAvailableApplicationSections(cards: []); _ = displayed(f); ApplicationConfig.shared.updateAvailableApplicationSections(cards: [Cards.pooledAssets.id]); XCTAssertTrue(displayed(f).contains { $0 is PoolsItem }); XCTAssertFalse(try row(PoolsItem.self, f).isHidden) }
    func testPoolAvailabilityRemovesUnavailablePoolPreference() async { let f = make(); load(f); f.edit.completion?(false); await wait(); XCTAssertEqual(f.edit.viewModels.map(\.id), [Cards.referralProgram.id]); XCTAssertFalse(ApplicationConfig.shared.getAvailableApplicationSections().contains(Cards.pooledAssets.id)) }
    func testPoolAvailabilityKeepsBothCardChoices() async { let f = make(); load(f); f.edit.completion?(true); await wait(); XCTAssertEqual(f.edit.viewModels.map(\.id), Cards.allCases.map(\.id)) }
    func testPoolAvailabilityRefreshReloadsTheExistingPoolItem() async throws { let f = make(); load(f); let pool = try row(PoolsItem.self, f); var reloaded: [SoramitsuTableViewItemProtocol] = []; f.model.reloadItem = { reloaded += $0 }; f.edit.completion?(false); await wait(); XCTAssertTrue(reloaded.contains { $0 === pool }); XCTAssertTrue(pool.isHidden) }
    func testReferralCardOpensTheReferralFlow() throws { let f = make(); load(f); try row(FriendsItem.self, f).onTap?(); XCTAssertEqual(f.route.calls, ["showReferralProgram"]) }
    func testBackupCardOpensOptionsForTheBoundWallet() throws { let f = make(); load(f); try row(BackupItem.self, f).onTap?(); XCTAssertEqual(f.route.optionAccount?.address, owner.address) }
    func testEditCardKeepsTheSameServicesAndRefreshesAfterEditing() throws { let f = make(); load(f); try row(EditViewItem.self, f).onTap?(); XCTAssertEqual(f.route.calls, ["showEditView"]); XCTAssertTrue(f.route.editService === f.edit); var rendered = 0; f.model.setupItems = { _ in rendered += 1 }; f.route.editCompletion?(); XCTAssertEqual(rendered, 1) }
    func testPoolExpandArrowTogglesTheCurrentItemAndReloads() throws { let f = make(); load(f); let pool = try row(PoolsItem.self, f); let was = pool.isExpand; var count = 0; f.model.reloadItem = { _ in count += 1 }; pool.arrowButtonHandler?(); XCTAssertEqual(pool.isExpand, !was); pool.arrowButtonHandler?(); XCTAssertEqual(pool.isExpand, was); XCTAssertEqual(count, 2) }
    func testPoolSeeAllOpensPoolList() throws { let f = make(); load(f); try row(PoolsItem.self, f).expandButtonHandler?(); XCTAssertEqual(f.route.calls, ["showFullListPools"]) }
    func testRemovedPoolDoesNotOpenStaleDetails() throws { let f = make(); load(f); try row(PoolsItem.self, f).poolHandler?("removed"); XCTAssertTrue(f.route.calls.isEmpty) }
    func testPoolSelectionOpensItsMatchingDetails() throws { let f = make(); load(f); f.pools.pool = PoolInfo(baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue, poolId: "selected", accountId: owner.address); try row(PoolsItem.self, f).poolHandler?("selected"); XCTAssertEqual(f.route.poolId, "selected") }
    func testFullAssetListReceivesTheBoundAddressAndUpdateCallback() { let f = make(); f.model.showFullListAssets(); XCTAssertEqual(f.route.assetAddress, owner.address); XCTAssertNotNil(f.route.updateHandler) }
    func testFullPoolListReceivesAnUpdateCallback() { let f = make(); f.model.showFullListPools(); XCTAssertEqual(f.route.calls, ["showFullListPools"]); XCTAssertNotNil(f.route.updateHandler) }
    func testAssetChangeRefreshesPortfolioButPoolChangeDoesNot() async { let f = make(); f.model.updateAssets(updatedSection: .pools); await wait(); XCTAssertEqual(f.source.refreshes, 0); f.model.updateAssets(updatedSection: .assets); await wait(); XCTAssertEqual(f.source.refreshes, 1) }
    func testSingleNetworkSendUsesTheExistingSoraFlow() { let f = make(); f.model.sendFromWallet(); XCTAssertEqual(f.route.calls, ["showSend"]); XCTAssertEqual(f.route.recipient, ""); XCTAssertNil(f.route.token) }
    func testSingleNetworkReceiveRunsItsProvidedActionOnce() { let f = make(); var calls = 0; f.model.receive { calls += 1 }; XCTAssertEqual(calls, 1) }
    func testBackupEventRendersCurrentPreferencesAgain() { let f = make(); load(f); var renders = 0; f.model.setupItems = { _ in renders += 1 }; f.model.processAccountBackuped(event: AccountBackuped()); XCTAssertEqual(renders, 1) }
    func testWalletCardsDoNotRetainTheViewModelAfterLeavingTheScreen() { weak var weakModel: RedesignWalletViewModel?; autoreleasepool { let f = make(); load(f); weakModel = f.model }; XCTAssertNil(weakModel) }
    func testRealDashboardControllerLoadsOnlyOneTableAndBindsItsModel() { let f = make(); let screen = RedesignWalletViewController(viewModel: f.model); f.model.view = screen; screen.loadViewIfNeeded(); screen.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844); screen.view.layoutIfNeeded(); XCTAssertEqual(screen.view.subviews.filter { $0 is SoramitsuTableView }.count, 1); XCTAssertEqual(f.model.walletItems.count, 4) }
    func testDashboardLifecycleStartsAndStopsThePortfolioSource() { let f = make(); let screen = RedesignWalletViewController(viewModel: f.model); f.model.view = screen; screen.loadViewIfNeeded(); screen.viewWillAppear(false); screen.viewDidAppear(false); XCTAssertEqual(f.source.starts, 1); XCTAssertTrue(f.model.portfolioHome.heroItem.isSkyVisible); screen.viewDidDisappear(false); XCTAssertEqual(f.source.stops, 1); XCTAssertFalse(f.model.portfolioHome.heroItem.isSkyVisible) }
    func testPortfolioRouterForwardsSendToTheWalletNetworkChoice() { let f = make(); PortfolioWalletRouter(wallet: f.model).showSend(from: f.view); XCTAssertEqual(f.route.calls, ["showSend"]) }
    func testPortfolioReceiveForwardsTheSelectedAddressAndName() { let f = make(); PortfolioWalletRouter(wallet: f.model).showSora2Receive(from: f.view); XCTAssertEqual(f.route.qrAddress, owner.address); XCTAssertEqual(f.route.qrName, owner.username) }
    func testPortfolioReceiveWithNoAccountDoesNotOpenAnEmptyQR() { let f = make(); SelectedWalletSettings.shared.commitInternalValue(nil); PortfolioWalletRouter(wallet: f.model).showSora2Receive(from: f.view); XCTAssertTrue(f.route.calls.isEmpty) }
}

@MainActor private final class DashboardSource: PortfolioDataSource {
    var snapshot = PortfolioSnapshot(wallets: [], holdings: [], networks: [.sora2], swapsAvailable: false, swapDisclaimerAccepted: false, liveNetworks: [.sora2])
    var onChange: ((PortfolioSnapshot) -> Void)?
    var isSample: Bool { true }
    var starts = 0, stops = 0, refreshes = 0
    func start() { starts += 1; onChange?(snapshot) }
    func stop() { stops += 1 }
    func refreshAll() { refreshes += 1; onChange?(snapshot) }
    func asset(_ id: String) -> (symbol: String, icon: String?)? { nil }
}
private final class DashboardEdit: EditViewServiceProtocol { var viewModels: [EnabledViewModel] = []; var completion: ((Bool) -> Void)?; func loadModels(completion: ((Bool) -> Void)?) { self.completion = completion }; func loaded(pools: [PoolInfo]) {} }
private final class DashboardView: UIViewController, RedesignWalletViewProtocol {}
private final class DashboardAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets = [AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true),
        AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18, icon: nil, displayName: "Validator", visible: true),
        AssetInfo(id: "custom-zero", symbol: "ZERO", chainId: "", precision: 18, icon: nil, displayName: "Zero asset", visible: false),
        AssetInfo(id: "custom-unknown", symbol: "UNKNOWN", chainId: "", precision: 18, icon: nil, displayName: "Unread asset", visible: false)]
    var saved: [[AssetInfo]] = []
    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.identifier == identifier } }
    func getAssetList() -> [AssetInfo]? { assets }
    func updateAssetList(_ list: [AssetInfo]) {}
    func saveAssetList(_ list: [AssetInfo]) { saved.append(list) }
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { 2 }
    func setup(for accountSettings: SelectedWalletSettings) {}
}
private actor DashboardFiat: FiatServiceProtocol { func getFiat() async -> [PIExactFiatData] { [] } }
private final class DashboardMarket: MarketCapServiceProtocol { func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] } }
private final class DashboardBalances: AssetProviderProtocol {
    var balances: [BalanceData] = []; var unavailable: Set<String> = []; var additions = 0
    func getBalances(with assetIds: [String]) -> [BalanceData] { balances.filter { assetIds.contains($0.identifier) } }
    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> { unavailable.intersection(assetIds) }
    func add(observer: AssetProviderObserverProtocol) { additions += 1 }
    func remove(observer: AssetProviderObserverProtocol) {}
}

private final class DashboardQR: WalletQREncoderProtocol {
    func encode(receiverInfo _: ReceiveInfo) throws -> Data {
        Data("substrate:test".utf8)
    }
}
private struct DashboardShare: AccountShareFactoryProtocol {
    func createSources(for _: ReceiveInfo, qrImage _: UIImage) -> [Any] { [] }
}
private final class DashboardPools: PoolsServiceInputProtocol {
    let state = PoolNetworkState(isPresented: false, isEnabled: false)
    var pool: PoolInfo? = nil

    func loadAccountPools() {}
    func getAccountPools() -> [PoolInfo] { pool.map { [$0] } ?? [] }
    var saved: [[PoolInfo]] = []
    func updatePools(_ pools: [PoolInfo]) { saved.append(pools) }
    func getPool(by _: String) -> PoolInfo? { pool }
    func getPool(by _: String, targetAssetId _: String) async -> PoolInfo? { pool }
    func loadPool(by _: String, targetAssetId _: String) async -> PoolInfo? { pool }
    func loadPairState(baseAssetId _: String, targetAssetId _: String) async throws -> PoolNetworkState { state }
    func loadPools(currentAsset _: AssetInfo) -> [PoolInfo] { [] }
    func loadTargetPools(for _: String) -> [PoolInfo] { [] }
    func appendDelegate(delegate _: PoolsServiceOutput) {}
}
private final class DashboardFarms: DemeterFarmingServiceProtocol {
    func getUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?) async -> [UserFarm] { [] }
    func loadUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?, accountId _: Data) async throws -> [UserFarm] { [] }
    func getAllFarms() async throws -> [Farm] { [] }
    func getFarm(with _: String) -> Farm? { nil }
    func getFarmDetails(baseAssetId _: String, poolAssetId _: String, rewardAssetId _: String) async throws -> [Farm] { [] }
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) { completion([]) }
}

private final class DashboardReferrals: ReferralsOperationFactoryProtocol {
    func createReferrerBalancesOperation() -> JSONRPCListOperation<JSONScaleDecodable<SoraPassport.Balance>>? { nil }
    func createExtrinsicSetReferrerOperation(with _: String) -> BaseOperation<String> {
        ClosureOperation { "" }
    }
    func createExtrinsicReserveReferralBalanceOperation(with _: BigUInt) -> BaseOperation<String> {
        ClosureOperation { "" }
    }
    func createExtrinsicUnreserveReferralBalanceOperation(with _: BigUInt) -> BaseOperation<String> {
        ClosureOperation { "" }
    }
    func createReferrerOperation() -> JSONRPCListOperation<String?>? { nil }
}
private final class DashboardEngine: JSONRPCEngine {
    var url: URL?; var pendingEngineRequests: [JSONRPCRequest] { [] }
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 { XCTFail("Unexpected network request"); throw CancellationError() }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 { XCTFail("Unexpected subscription"); throw CancellationError() }
    func cancelForIdentifier(_ identifier: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_ subscription: JSONRPCSubscribing) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ identifier: UInt16) throws {}
}

private final class DashboardRoute: RedesignWalletWireframeProtocol {
    var calls: [String] = []
    var optionAccount: AccountItem?, assetAddress: String?, poolId: String?, recipient: String?, token: String?, qrAddress: String?, qrName: String?
    var editService: EditViewServiceProtocol?, editCompletion: (() -> Void)?, updateHandler: ((UpdatedSection) -> Void)?
    func showFullListAssets(on controller: UIViewController?,
                            assetManager: AssetManagerProtocol,
                            fiatService: FiatServiceProtocol,
                            assetViewModelFactory: AssetViewModelFactory,
                            providerFactory: BalanceProviderFactory,
                            poolsService: PoolsServiceInputProtocol,
                            networkFacade: WalletNetworkOperationFactoryProtocol?,
                            accountId: String,
                            address: String,
                            polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                            qrEncoder: WalletQREncoderProtocol,
                            sharingFactory: AccountShareFactoryProtocol,
                            referralFactory: ReferralsOperationFactoryProtocol,
                            assetsProvider: AssetProviderProtocol,
                            marketCapService: MarketCapServiceProtocol,
                            farmingService: DemeterFarmingServiceProtocol,
                            updateHandler: ((UpdatedSection) -> Void)?) { calls.append("showFullListAssets"); assetAddress = address; self.updateHandler = updateHandler }
    func showFullListPools(on controller: UIViewController?,
                           poolsService: PoolsServiceInputProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           poolViewModelFactory: PoolViewModelFactory,
                           providerFactory: BalanceProviderFactory,
                           operationFactory: WalletNetworkOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol,
                           marketCapService: MarketCapServiceProtocol,
                           farmingService: DemeterFarmingServiceProtocol,
                           updateHandler: ((UpdatedSection) -> Void)?) { calls.append("showFullListPools"); self.updateHandler = updateHandler }
    func showPoolDetails(on viewController: UIViewController?,
                         poolInfo: PoolInfo,
                         assetManager: AssetManagerProtocol,
                         fiatService: FiatServiceProtocol,
                         poolsService: PoolsServiceInputProtocol,
                         providerFactory: BalanceProviderFactory,
                         operationFactory: WalletNetworkOperationFactoryProtocol,
                         assetsProvider: AssetProviderProtocol,
                         marketCapService: MarketCapServiceProtocol,
                         farmingService: DemeterFarmingServiceProtocol) { calls.append("showPoolDetails"); poolId = poolInfo.poolId }
    func showManageAccount(on view: UIViewController, completion: @escaping () -> Void) { calls.append("showManageAccount") }
    func showGenerateQR(on controller: UIViewController?,
                        accountId: String,
                        address: String,
                        username: String,
                        qrEncoder: WalletQREncoderProtocol,
                        sharingFactory: AccountShareFactoryProtocol,
                        assetManager: AssetManagerProtocol?,
                        assetsProvider: AssetProviderProtocol?,
                        networkFacade: WalletNetworkOperationFactoryProtocol,
                        providerFactory: BalanceProviderFactory,
                        isScanQRShown: Bool,
                        marketCapService: MarketCapServiceProtocol,
                        closeHandler: (() -> Void)?) { calls.append("showGenerateQR"); qrAddress = address; qrName = username }
    func showSend(on controller: UIViewController?,
                  selectedTokenId: String?,
                  selectedAddress: String,
                  fiatService: FiatServiceProtocol?,
                  assetManager: AssetManagerProtocol?,
                  providerFactory: BalanceProviderFactory,
                  networkFacade: WalletNetworkOperationFactoryProtocol?,
                  assetsProvider: AssetProviderProtocol,
                  qrEncoder: WalletQREncoderProtocol,
                  sharingFactory: AccountShareFactoryProtocol,
                  marketCapService: MarketCapServiceProtocol) { calls.append("showSend"); recipient = selectedAddress; token = selectedTokenId }
    func showReferralProgram(from view: RedesignWalletViewProtocol?,
                             walletContext: CommonWalletContextProtocol,
                             assetManager: AssetManagerProtocol) { calls.append("showReferralProgram") }
    func showEditView(from view: RedesignWalletViewProtocol?,
                      poolsService: PoolsServiceInputProtocol,
                      editViewService: EditViewServiceProtocol,
                      completion: (() -> Void)?) { calls.append("showEditView"); editService = editViewService; editCompletion = completion }
    func showAccountOptions(from view: RedesignWalletViewProtocol?,
                            account: AccountItem?) { calls.append("showAccountOptions"); optionAccount = account }
}
