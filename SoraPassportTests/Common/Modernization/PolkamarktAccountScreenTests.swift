// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class PolkamarktAccountScreenTests: XCTestCase {
    private var fixture: RuntimeScreenFixture!, session: URLSession!, directory: URL!, window: UIWindow!, navigation: UINavigationController!
    private var previousWindow: UIWindow?, previousAccount: AccountItem?, previousLanguage = "en", previousFeature = false, animations = true
    private let server = AccountMarketIndexer()
    override func setUpWithError() throws {
        try super.setUpWithError(); fixture = try RuntimeScreenFixture(); previousAccount = SelectedWalletSettings.shared.currentAccount; SelectedWalletSettings.shared.commitInternalValue(fixture.account)
        previousLanguage = LocalizationManager.shared.selectedLocalization; LocalizationManager.shared.selectedLocalization = "en"
        previousFeature = SettingsManager.shared.polkamarktEnabled; SettingsManager.shared.polkamarktEnabled = true
        animations = UIView.areAnimationsEnabled; UIView.setAnimationsEnabled(false)
        server.owner = fixture.account.address; PIStubIndexerProtocol.install { [server] in server.respond($0) }; session = PIStubIndexerProtocol.session(); directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        previousWindow = scene?.windows.first { $0.isKeyWindow }; window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
        window.frame = scene?.coordinateSpace.bounds ?? UIScreen.main.bounds
    }
    override func tearDown() async throws {
        let released = (navigation?.viewControllers ?? []).map { RuntimeScreenWeakController($0) }
        navigation?.setViewControllers([], animated: false)
        window?.isHidden = true; window?.rootViewController = nil; navigation = nil; window = nil
        await wait { released.allSatisfy { $0.value == nil } }
        fixture?.cleanup(); fixture = nil; session?.invalidateAndCancel(); PIStubIndexerProtocol.uninstall(); try? FileManager.default.removeItem(at: directory)
        SelectedWalletSettings.shared.commitInternalValue(previousAccount); SettingsManager.shared.polkamarktEnabled = previousFeature; LocalizationManager.shared.selectedLocalization = previousLanguage
        UIView.setAnimationsEnabled(animations); previousWindow?.makeKeyAndVisible(); try await super.tearDown()
    }
    private func wait(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<1000 { if condition() { return }; try? await Task.sleep(nanoseconds:10_000_000) }; XCTFail("Account screen did not finish its local read",file:file,line:line)
    }
    private func catalog() async -> PolkamarktViewController {
        let client = PIIndexerClient(session:session,historyShapeMemory:PIHistoryShapeMemory(),cacheDirectory:directory,retryPause:{ _ in })
        let c = PolkamarktViewController(walletContext:fixture.context,client:client); navigation = UINavigationController(rootViewController:c); window.rootViewController = navigation; window.makeKeyAndVisible(); c.loadViewIfNeeded()
        await wait { c.tableView.numberOfRows(inSection:2) == 1 && PIStubIndexerProtocol.requests.contains("MobilePolkamarktPositions") }
        await wait { c.refreshControl?.isRefreshing != true }
        return c
    }
    private func content(_ c: UITableViewController, _ section: Int, _ row: Int = 0) -> UIListContentConfiguration? { c.tableView(c.tableView,cellForRowAt:IndexPath(row:row,section:section)).contentConfiguration as? UIListContentConfiguration }
    private func cell(_ c: UITableViewController, _ section: Int, _ row: Int = 0) -> UITableViewCell { c.tableView(c.tableView,cellForRowAt:IndexPath(row:row,section:section)) }
    private func detail(position: Bool = false) async throws -> UITableViewController {
        let c = await catalog(); c.tableView(c.tableView,didSelectRowAt:IndexPath(row:0,section:position ? 1 : 2))
        await wait { self.navigation.topViewController !== c }; let d = try XCTUnwrap(navigation.topViewController as? UITableViewController)
        await wait { d.tableView.tableHeaderView is PolkamarktLineChartView && PIStubIndexerProtocol.requests.contains("MobilePolkamarktTrades") }
        await wait { d.refreshControl?.isRefreshing != true }; return d
    }
    func testSelectedWalletPositionsDisplayExactSharesAndValue() async { let c = await catalog(); XCTAssertEqual(content(c,1)?.text,"Runtime-backed market"); let value = content(c,1)?.secondaryText ?? ""; XCTAssertTrue(value.contains("YES 12.5 shares")); XCTAssertTrue(value.contains("Value $9.25")); XCTAssertTrue(value.contains("Unrealized P/L $-0.25")) }
    func testIndexedPositionsRemainReadOnlyWithoutMutationQualification() async { let c = await catalog(); XCTAssertEqual(c.navigationItem.rightBarButtonItems?.map(\.title),["Filters"]); XCTAssertEqual(fixture.extrinsics.prepareCount,0) }
    func testMissingPositionsShowAnEmptyState() async { server.emptyPositions = true; let c = await catalog(); XCTAssertEqual(content(c,1)?.text,"No indexed positions") }
    func testUnavailablePositionReadShowsItsError() async { server.failures = ["MobilePolkamarktPositions"]; let c = await catalog(); await wait { self.content(c,1)?.text == "Indexed positions are unavailable." }; XCTAssertEqual(c.tableView.numberOfRows(inSection:1),1) }
    func testPositionWithoutOutcomeShowsBothShareBalances() async { server.positionOverride = ["outcome":NSNull(),"shares":NSNull()]; let c = await catalog(); let text = content(c,1)?.secondaryText ?? ""; XCTAssertTrue(text.contains("Yes 12")); XCTAssertTrue(text.contains("No 2")) }
    func testPositionUsesRealizedPnlWhenUnrealizedPnlIsAbsent() async { server.positionOverride = ["unrealizedPnlUsd":NSNull()]; let c = await catalog(); XCTAssertTrue(content(c,1)?.secondaryText?.contains("Realized P/L $1.5") == true) }
    func testOpeningAPositionUsesItsExactMarket() async throws { let d = try await detail(position:true); XCTAssertEqual(d.title,"Runtime-backed market"); XCTAssertEqual(cell(d,0).detailTextLabel?.text,"OPEN") }
    func testDetailUsesFinalizedPricesInsteadOfIndexedProbability() async throws { let d = try await detail(); XCTAssertEqual(cell(d,0,1).detailTextLabel?.text,"55.00%"); XCTAssertEqual(cell(d,0,2).detailTextLabel?.text,"45.00%") }
    func testDetailShowsExactRuntimeYesAndNoShares() async throws { let d = try await detail(); XCTAssertEqual(d.tableView.numberOfRows(inSection:1),3); XCTAssertEqual(cell(d,1,0).detailTextLabel?.text,PolkamarktAmountCodec.format(2000)); XCTAssertEqual(cell(d,1,1).detailTextLabel?.text,PolkamarktAmountCodec.format(1500)) }
    func testUnclaimablePositionHasNoClaimAction() async throws { let d = try await detail(); XCTAssertEqual(cell(d,1,2).accessoryType,.none); XCTAssertEqual(cell(d,1,2).selectionStyle,.none); XCTAssertFalse(d.navigationItem.rightBarButtonItem?.isEnabled ?? true) }
    func testDetailShowsIndexedVolumeAndLiquidityAsIndexed() async throws { let d = try await detail(); XCTAssertEqual(cell(d,0,3).textLabel?.text,"Indexed liquidity"); XCTAssertEqual(cell(d,0,3).detailTextLabel?.text,"123.45"); XCTAssertEqual(cell(d,0,4).detailTextLabel?.text,"456.78") }
    func testDetailDpmChartUsesFinalizedProbability() async throws { let d = try await detail(); let chart = try XCTUnwrap(d.tableView.tableHeaderView as? PolkamarktLineChartView); XCTAssertEqual(chart.caption,"Finalized DPM pricing curve"); XCTAssertEqual(chart.markerFraction,0.6); XCTAssertEqual(chart.values.count,PolkamarktRuntimeContract.dpmCurvePointCount) }
    func testDetailTradesShowBatchParticipationAndExactAmounts() async throws { let d = try await detail(); XCTAssertEqual(cell(d,2).textLabel?.text,"BUY · YES · 2 MARKETS"); XCTAssertEqual(cell(d,2).detailTextLabel?.text,"9007199254740993"); XCTAssertEqual(d.tableView.numberOfRows(inSection:2),1) }
    func testDetailFiltersTradesForOtherMarkets() async throws { server.otherMarketTrade = true; let d = try await detail(); XCTAssertEqual(cell(d,2).textLabel?.text,"No indexed trades") }
    func testDetailTradeFailureShowsUnavailableRatherThanNoTrades() async throws { server.failures = ["MobilePolkamarktTrades"]; let d = try await detail(); XCTAssertEqual(cell(d,2).textLabel?.text,"Indexed trade history is unavailable.") }
    func testDetailMissingRuntimePositionDoesNotInventShares() async throws { fixture.server.claimMissing = true; let d = try await detail(); XCTAssertEqual(d.tableView.numberOfRows(inSection:1),1); XCTAssertEqual(cell(d,1).textLabel?.text,"No finalized runtime position") }
    func testDetailWrongRuntimeIdentityShowsUnavailable() async throws { fixture.server.stateId = 43; let d = try await detail(); XCTAssertEqual(cell(d,0).detailTextLabel?.text,"—"); XCTAssertEqual(cell(d,1).textLabel?.text,"Finalized SORA2 market state is unavailable."); XCTAssertFalse(d.navigationItem.rightBarButtonItem?.isEnabled ?? true) }
    func testRuntimeClosedMarketIsShownAsLocked() async throws { fixture.server.market = fixture.markets["Open400"]!; let d = try await detail(); XCTAssertEqual(cell(d,0).detailTextLabel?.text,"LOCKED") }
    func testDetailEmptyPendingOverlayDoesNotClaimARecoveryFailure() async throws { let d = try await detail(); XCTAssertEqual(cell(d,3).textLabel?.text,"No pending transaction"); XCTAssertEqual(cell(d,3).selectionStyle,.none) }
    func testDetailReappearanceWithChangedWalletReturnsToCatalog() async throws { let d = try await detail(); SelectedWalletSettings.shared.commitInternalValue(nil); d.beginAppearanceTransition(true,animated:false); d.endAppearanceTransition(); XCTAssertFalse(navigation.viewControllers.contains { $0 === d }) }
    func testCatalogClearsAnotherWalletsPositionsImmediately() async { let c = await catalog(); SelectedWalletSettings.shared.commitInternalValue(nil); XCTAssertEqual(content(c,1)?.text,"Connect a SORA2 wallet to see positions") }
    func testRefreshReplacesRuntimeSharesInsteadOfKeepingOldPosition() async throws { let d = try await detail(); fixture.server.yesShares = "12345"; d.refreshControl?.sendActions(for:.valueChanged); await wait { self.cell(d,1,0).detailTextLabel?.text == PolkamarktAmountCodec.format(12345) }; XCTAssertEqual(fixture.extrinsics.prepareCount,0) }
    private func interactiveDetail(allowsMutations: @escaping () -> Bool = { true }) async throws -> PolkamarktMarketViewController {
        fixture.server.kusd = "10000000000000000000"; fixture.server.xor = "20000000000000000000"
        fixture.server.noShares = "5000000000000000000"
        fixture.server.buyOverrides = ["collateralIn": "1000000000000000000", "feeAmount": "5000000000000000", "pricingCollateral": "995000000000000000", "sharesOut": "2222000000000000000"]
        fixture.server.sellOverrides = ["sharesIn": "1000000000000000000", "grossCollateralOut": "556000000000000000", "feeAmount": "1000000000000000", "collateralOut": "555000000000000000"]
        fixture.extrinsics.rawFee = "7000000000000000"
        let client = PIIndexerClient(session: session, historyShapeMemory: PIHistoryShapeMemory(), cacheDirectory: directory, retryPause: { _ in })
        let market = try JSONDecoder().decode(PIMarket.self, from: Data(#"{"id":"market-42","marketId":42,"title":"Runtime-backed market","status":"Open","mechanism":"DynamicParimutuel"}"#.utf8))
        let detail = PolkamarktMarketViewController(market: market, client: client, coordinator: fixture.subject, pendingStore: try PolkamarktPendingStore(baseURL: fixture.directory), account: fixture.account.address, marketDataFromCache: false, mutationsAllowed: allowsMutations)
        navigation = UINavigationController(rootViewController: detail); window.rootViewController = navigation; window.makeKeyAndVisible(); detail.loadViewIfNeeded()
        await wait { detail.tableView.tableHeaderView is PolkamarktLineChartView && PIStubIndexerProtocol.requests.contains("MobilePolkamarktTrades") }
        await wait { detail.refreshControl?.isRefreshing != true }
        return detail
    }
    private func alert(_ controller: UIViewController) async throws -> UIAlertController {
        await wait { controller.presentedViewController is UIAlertController }
        return try XCTUnwrap(controller.presentedViewController as? UIAlertController)
    }
    func testTradeInputExplainsBuyAssetAndUsesDecimalKeyboards() async throws {
        let d = try await interactiveDetail(); d.presentTradeInput(side: .buy, outcome: .yes)
        let a = try await alert(d); XCTAssertEqual(a.title, "Buy Yes"); XCTAssertTrue(a.message?.contains("Enter KUSD") == true)
        XCTAssertEqual(a.textFields?.count, 2); XCTAssertTrue(a.textFields?.allSatisfy { $0.keyboardType == .decimalPad } == true)
        XCTAssertEqual(a.textFields?[1].text, "0.5"); XCTAssertEqual(a.actions.map(\.title), ["Cancel", "Get quote"])
    }
    func testSellInputNamesTheReviewedOutcomeShares() async throws {
        let d = try await interactiveDetail(); d.presentTradeInput(side: .sell, outcome: .no)
        let a = try await alert(d); XCTAssertEqual(a.title, "Sell No"); XCTAssertTrue(a.message?.contains("Enter No shares") == true)
    }
    func testInvalidAmountShowsAnErrorWithoutPreparingAnExtrinsic() async throws {
        let d = try await interactiveDetail(); d.loadQuote(side: .buy, outcome: .yes, amount: "-1", slippage: "0.5")
        let a = try await alert(d); XCTAssertEqual(a.title, "Invalid amount"); XCTAssertEqual(fixture.extrinsics.prepareCount, 0)
    }
    func testInvalidSlippageShowsAnErrorBeforeRuntimeQuote() async throws {
        let d = try await interactiveDetail(); d.loadQuote(side: .buy, outcome: .yes, amount: "1", slippage: "0.001")
        let a = try await alert(d); XCTAssertEqual(a.title, "Invalid amount"); XCTAssertEqual(fixture.extrinsics.prepareCount, 0)
    }
    func testBuyQuoteReviewShowsExactAmountsFeesAndFinalizedStatus() async throws {
        let d = try await interactiveDetail(); d.loadQuote(side: .buy, outcome: .yes, amount: "1", slippage: "1")
        let a = try await alert(d); XCTAssertEqual(a.title, "Confirm Buy Yes")
        let text = a.message ?? ""; XCTAssertTrue(text.contains("Input: 1 KUSD")); XCTAssertTrue(text.contains("Authoritative status: Open")); XCTAssertTrue(text.contains("Closes at block: 500"))
        XCTAssertTrue(text.contains("2.222")); XCTAssertTrue(text.contains("0.007"))
        XCTAssertEqual(a.actions.map(\.title), ["Cancel", "Sign trade"]); XCTAssertEqual(a.actions.last?.style, .destructive)
        XCTAssertEqual(fixture.extrinsics.submitCount, 0); XCTAssertEqual(fixture.extrinsics.preparedSubmitCount, 0)
    }
    func testSellQuoteReviewKeepsSharesAndCollateralUnitsDistinct() async throws {
        let d = try await interactiveDetail(); d.loadQuote(side: .sell, outcome: .no, amount: "1", slippage: "1")
        let a = try await alert(d); XCTAssertEqual(a.title, "Confirm Sell No")
        XCTAssertTrue(a.message?.contains("Input: 1 No shares") == true)
        XCTAssertTrue(a.message?.contains("0.555 KUSD") == true)
        XCTAssertEqual(fixture.extrinsics.preparedSubmitCount, 0)
    }
    func testFeeFailureIsPresentedAsQuoteUnavailable() async throws {
        let d = try await interactiveDetail(); fixture.extrinsics.failure = RuntimeScreenFailure.offline
        d.loadQuote(side: .buy, outcome: .yes, amount: "1", slippage: "1")
        let a = try await alert(d); XCTAssertEqual(a.title, "Quote unavailable"); XCTAssertTrue(d.navigationItem.rightBarButtonItem?.isEnabled == true)
    }
    func testQuoteCannotBePresentedAfterSelectedWalletChanges() async throws {
        let d = try await interactiveDetail(); SelectedWalletSettings.shared.commitInternalValue(nil)
        d.loadQuote(side: .buy, outcome: .yes, amount: "1", slippage: "1")
        XCTAssertNil(d.presentedViewController); XCTAssertEqual(fixture.extrinsics.prepareCount, 0)
    }
    func testDisabledMutationPolicyShowsPausedTradeExplanation() async throws {
        let d = try await interactiveDetail(allowsMutations: { false }); let button = try XCTUnwrap(d.navigationItem.rightBarButtonItem)
        XCTAssertFalse(button.isEnabled); _ = d.perform(try XCTUnwrap(button.action))
        let a = try await alert(d); XCTAssertEqual(a.title, "Trading paused")
    }
    func testOpenMarketTradeMenuListsAllFourChoices() async throws {
        let d = try await interactiveDetail(); let button = try XCTUnwrap(d.navigationItem.rightBarButtonItem)
        XCTAssertTrue(button.isEnabled); _ = d.perform(try XCTUnwrap(button.action))
        let a = try await alert(d); XCTAssertEqual(a.actions.map(\.title), ["Buy Yes", "Buy No", "Sell Yes", "Sell No", "Cancel"])
    }
    func testClosedMarketCannotOpenTradeInput() async throws {
        fixture.server.market = fixture.markets["Open400"]!
        let d = try await interactiveDetail(); let button = try XCTUnwrap(d.navigationItem.rightBarButtonItem)
        XCTAssertFalse(button.isEnabled); _ = d.perform(try XCTUnwrap(button.action))
        let a = try await alert(d); XCTAssertEqual(a.title, "Trading unavailable")
    }
    func testDisabledClaimsExplainWhyTheyArePaused() async throws {
        let d = try await interactiveDetail(allowsMutations: { false }); d.presentClaims()
        let a = try await alert(d); XCTAssertEqual(a.title, "Claims paused")
    }
    func testUnclaimableOpenMarketDoesNotOfferASubmission() async throws {
        let d = try await interactiveDetail()
        XCTAssertEqual(cell(d, 0).detailTextLabel?.text, "OPEN")
        XCTAssertEqual(cell(d, 1, 2).accessoryType, .none)
        d.presentClaims()
        XCTAssertNil(d.presentedViewController); XCTAssertEqual(fixture.extrinsics.preparedSubmitCount, 0)
    }
    func testClaimOperationFailureIsPresentedAndReloadsFinalizedState() async throws {
        let d = try await interactiveDetail(); d.submitClaim { throw RuntimeScreenFailure.offline }
        let a = try await alert(d); XCTAssertEqual(a.title, "Claim not completed")
        await wait { d.navigationItem.rightBarButtonItem?.isEnabled == true }
    }
    func testDisabledClaimsNeverRunTheirOperation() async throws {
        let d = try await interactiveDetail(allowsMutations: { false }); var ran = false
        d.submitClaim { ran = true; throw RuntimeScreenFailure.unexpected }
        XCTAssertFalse(ran); XCTAssertNil(d.presentedViewController)
    }
    func testSuccessfulClaimShowsItsExactPendingHash() async throws {
        let d = try await interactiveDetail(); let owner = fixture.account.address
        d.submitClaim { PolkamarktPendingMutation(id: UUID(), account: owner, action: "claim", marketIds: [42], createdAt: Date(), updatedAt: Date(), extrinsicHash: "0x" + String(repeating: "ab", count: 32), state: .submitted, finalizedBlock: nil, errorClass: nil) }
        let a = try await alert(d); XCTAssertEqual(a.title, "Claim submitted"); XCTAssertEqual(a.message, "0x" + String(repeating: "ab", count: 32))
    }
    func testClaimWithoutKnownHashDescribesPendingReconciliation() async throws {
        let d = try await interactiveDetail(); let owner = fixture.account.address
        d.submitClaim { PolkamarktPendingMutation(id: UUID(), account: owner, action: "claim", marketIds: [42], createdAt: Date(), updatedAt: Date(), extrinsicHash: nil, state: .submissionUnknown, finalizedBlock: nil, errorClass: nil) }
        let a = try await alert(d); XCTAssertEqual(a.title, "Claim submitted"); XCTAssertEqual(a.message, "Pending reconciliation.")
    }
    func testSlippagePercentRoundTripsEveryAdmittedBasisPoint() throws {
        for value in PolkamarktRuntimeContract.minimumMobileSlippageBasisPoints...PolkamarktRuntimeContract.maximumMobileSlippageBasisPoints {
            XCTAssertEqual(try PolkamarktMarketViewController.slippageBasisPoints(PolkamarktMarketViewController.slippagePercent(value)), value)
        }
    }
    func testSlippageParsingRejectsAmbiguousAndOutOfRangeValues() {
        for value in ["", "0", "0.00", "-1", "+1", ".5", "01", "1.", "1.000", "1,5", "1e1", "10.01", "100.01", "101", "65536", "NaN", "∞"] {
            XCTAssertThrowsError(try PolkamarktMarketViewController.slippageBasisPoints(value), value)
        }
    }
    func testSlippageParsingTrimsOuterWhitespaceAndFormatsWithoutTrailingZeros() throws {
        XCTAssertEqual(try PolkamarktMarketViewController.slippageBasisPoints(" \n0.5\t"), 50)
        XCTAssertEqual(PolkamarktMarketViewController.slippagePercent(1), "0.01")
        XCTAssertEqual(PolkamarktMarketViewController.slippagePercent(100), "1")
        XCTAssertEqual(PolkamarktMarketViewController.slippagePercent(101), "1.01")
    }
}
private final class AccountMarketIndexer {
    var positionCount = 1
    var owner = "", emptyPositions = false, positionOverride = [String:Any](), failures = Set<String>(), otherMarketTrade = false
    private func market(_ id: Int = 42) -> [String:Any] { ["id":"market-\(id)","marketId":id,"title":"Runtime-backed market","status":"Open","updatedAtBlock":900,"timestamp":100,"liquidityUSD":"123.45","volumeUSD":"456.78","probability":"20","mechanism":"DynamicParimutuel"] }
    func respond(_ request: PIStubIndexerProtocol.Request) -> PIStubIndexerProtocol.Response {
        if failures.contains(request.operation) { return .init(status:503,body:"{}") }
        if request.operation == "MobileHealth" { return .init(body:PIAdvancingIndexer.health(indexed:1000,finalized:1001,indexedAt:Int(Date().timeIntervalSince1970)-1)) }
        let name: String; let rows: [[String:Any]]
        switch request.operation {
        case "MobilePolkamarktMarkets": name = "markets"; rows = [market()]
        case "MobilePolkamarktPositions": name = "accountPositions"; rows = emptyPositions ? [] : (0..<positionCount).map { offset in ["id":"position-\(42 + offset)","account":owner,"marketId":42 + offset,"market":market(42 + offset),"status":"Open","outcome":"Yes","shares":"12.5","yesShares":"12","noShares":"2","marketValueUsd":"9.25","unrealizedPnlUsd":"-0.25","realizedPnlUsd":"1.5"].merging(positionOverride){_,v in v} }
        case "MobilePolkamarktTrades": name = "accountTrades"; let id = otherMarketTrade ? 43 : 42; rows = [["id":"trade-1","account":owner,"marketId":id,"marketIds":otherMarketTrade ? [43] : [42,43],"market":market(id),"side":"buy","outcome":"yes","shares":"9007199254740993","blockNumber":900,"blockHash":"0x"+String(repeating:"ab",count:32),"extrinsicHash":"0x"+String(repeating:"cd",count:32)]]
        case "MobilePolkamarktSnapshots": name = "marketSnapshots"; rows = [["id":"snapshot-1","marketId":42,"timestamp":100,"blockHeight":900,"type":"DEFAULT","priceYes":"0.2"]]
        case "MobilePolkamarktSignals": return .init(body:#"{"data":{"polkamarktSignals":{"totalVolumeUsd":"100","activeMarkets":1,"activeAccounts":1,"liquidityUsd":"10","liquiditySeries":[],"answerBreakdown":[]}}}"#)
        default: return .init(status:400,body:"{}")
        }
        let page: [String:Any] = ["nodes":rows,"pageInfo":["hasNextPage":false,"hasPreviousPage":false,"startCursor":"c1","endCursor":"c1"],"totalCount":rows.count]
        return .init(body:String(data:try! JSONSerialization.data(withJSONObject:["data":[name:page]]),encoding:.utf8)!)
    }
}
private enum RuntimeScreenFailure: Swift.Error { case offline, unexpected }
@MainActor
private final class RuntimeScreenFixture {
    let settings = InMemorySettingsManager(), server = RuntimeScreenServer(), extrinsics = RuntimeScreenExtrinsics()
    let account: AccountItem
    var selected: AccountItem?
    let directory: URL, session: URLSession, engine: Sora2BoundedHTTPJSONRPCEngine, runtime: RuntimeScreenRuntime
    let markets: [String: String]
    var subject: PolkamarktTransactionCoordinator!
    var context: RuntimeScreenContext!
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let metadata = try! Data(contentsOf: root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec130.scale"))
    static let coder: Result<RuntimeCoderFactory, Swift.Error> = Result {
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(chainId: PIIndexerClient.soraMainnetGenesis,
            runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(chain: PIIndexerClient.soraMainnetGenesis, version: 130, txVersion: 130, metadata: metadata, resolver: nil),
            ownTypes: Data(contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")), dataHasher: .twox256)
        return RuntimeCoderFactory(catalog: snapshot.typeRegistryCatalog, specVersion: 130, txVersion: 130, metadata: snapshot.metadata)
    }
    init() throws {
        let key = Data(repeating: 3, count: 32)
        account = AccountItem(address: try SS58AddressFactory().addressFromAccountId(data: key, type: SoraPassport.Chain.sora.addressType()), cryptoType: .sr25519, networkType: SoraPassport.Chain.sora.addressType(), username: "Public fixture", publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: false)
        selected = account; directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.root.appendingPathComponent("Fixtures/Modernization/polkamarkt-market-storage-v130.json"))) as! [String: Any]
        markets = object["markets"] as! [String: String]
        server.market = markets["Open500"]!; server.metadataHex = Self.metadata.toHex(includePrefix: true); server.owner = account.address
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [RuntimeScreenURLProtocol.self]
        session = URLSession(configuration: configuration)
        RuntimeScreenURLProtocol.handler = { [server] in try server.response($0) }
        engine = Sora2BoundedHTTPJSONRPCEngine(nodeURL: URL(string: "https://polkamarkt.test")!, session: session)
        runtime = RuntimeScreenRuntime(coder: try Self.coder.get())
        let accountSettings = WalletAccountSettings(accountId: key.toHex(), assets: [])
        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
        let chain = AnyDataProviderRepository(InMemoryDataProviderRepository<ChainStorageItem>())
        let ids = try ChainStorageIdFactory(chain: .sora); let signer = RuntimeScreenNoSigner()
        let node = WalletNetworkOperationFactory(engine: engine, requestFactory: requestFactory, runtimeService: runtime, accountSettings: accountSettings, cryptoType: .sr25519, accountSigner: signer, extrinsicService: extrinsics, dummySigner: signer, chainStorage: chain, localStorageIdFactory: ids)
        let facade = WalletNetworkFacade(accountSettings: accountSettings, nodeOperationFactory: node, coingeckoOperationFactory: RuntimeScreenPrices(), polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactory(engine: engine), chainStorage: chain, localStorageIdFactory: ids, txStorage: AnyDataProviderRepository(InMemoryDataProviderRepository<TransactionHistoryItem>()), contactsOperationFactory: RuntimeScreenContacts(), accountsRepository: AnyDataProviderRepository(InMemoryDataProviderRepository<AccountItem>()), address: account.address, networkType: SoraPassport.Chain.sora.addressType(), assetManager: RuntimeScreenAssets(), totalPriceAssetId: nil, runtimeService: runtime, requestFactory: requestFactory, engine: engine, demeterFarmingService: RuntimeScreenFarms())
        context = RuntimeScreenContext(facade: facade); settings.polkamarktEnabled = true
        subject = PolkamarktTransactionCoordinator(walletContext: context, pendingStore: try PolkamarktPendingStore(baseURL: directory), settings: settings, selectedAccount: { [weak self] in self?.selected })
    }
    func quote(side: PolkamarktSide = .buy, outcome: PolkamarktOutcome = .yes, input: BigUInt = 1000, slippage: UInt16 = 100) async throws -> PolkamarktQuoteConfirmation {
        try await subject.quote(account: account.address, marketId: 42, outcome: outcome, side: side, input: input, slippageBasisPoints: slippage)
    }
    func cleanup() { session.invalidateAndCancel(); RuntimeScreenURLProtocol.handler = nil; try? FileManager.default.removeItem(at: directory) }
}
private final class RuntimeScreenContext: CommonWalletContextProtocol {
    let facade: WalletNetworkFacade
    init(facade: WalletNetworkFacade) { self.facade = facade }
    var networkOperationFactory: WalletNetworkOperationFactoryProtocol { facade }
    func prepareAccountUpdateCommand() -> WalletCommandProtocol { WalletCommandMock() }
    func prepareLanguageSwitchCommand(with newLanguage: WalletLanguage) -> WalletCommandProtocol { WalletCommandMock() }
}
private final class RuntimeScreenRuntime: SoraPassport.RuntimeCodingServiceProtocol {
    let coder: RuntimeCoderFactoryProtocol; var failure: Swift.Error?
    init(coder: RuntimeCoderFactoryProtocol) { self.coder = coder }
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> { ClosureOperation { if let failure = self.failure { throw failure }; return self.coder } }
}
private final class RuntimeScreenServer {
    let block = "0x" + String(repeating: "ab", count: 32)
    var owner = "", claimOwner: String?, market: String?, metadataHex = "", genesis = PIIndexerClient.soraMainnetGenesis
    var stateId = 42, kusd = "10000", xor = "20000", yesShares = "2000", noShares = "1500", claimMissing = false
    var buyOverrides = [String: Any](), sellOverrides = [String: Any](), claimOverrides = [String: Any]()
    private let lock = NSLock(); private var recorded = [String]()
    var methods: [String] { lock.lock(); defer { lock.unlock() }; return recorded }
    func response(_ request: URLRequest) throws -> Data {
        let body: Data
        if let data = request.httpBody { body = data }
        else if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }; var data = Data(); var buffer = [UInt8](repeating: 0, count: 8192)
            while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(buffer, count: count) }; body = data
        } else { throw RuntimeScreenFailure.unexpected }
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any]); let method = try XCTUnwrap(object["method"] as? String)
        let params = object["params"] as? [Any] ?? []; lock.lock(); recorded.append(method); lock.unlock()
        let result: Any
        switch method {
        case SoraPassport.RPCMethod.getBlockHash: result = genesis
        case SoraPassport.RPCMethod.getRuntimeMetadata: result = metadataHex
        case SoraPassport.RPCMethod.getHead: result = block
        case SoraPassport.RPCMethod.getHeader: result = ["number": "0x190", "parentHash": block, "extrinsicsRoot": block, "stateRoot": block, "digest": ["logs": []]]
        case SoraPassport.RPCMethod.queryStorageAt:
            let keys = try XCTUnwrap(params.first as? [String]); XCTAssertEqual(keys, ["0x7c9df7ef418f869f0ab365233bda527fd8426954fc0e154310293fc43493f5829017d1c733ec2aeaa6fd0230614e397e2a000000"]); result = [["block": block, "changes": keys.map { [$0, market as Any? ?? NSNull()] }]]
        case PolkamarktRuntimeContract.RPC.marketState:
            result = ["marketId": stateId, "mechanism": "DynamicParimutuel", "virtualDepth": "100", "realYesShares": "6000", "realNoShares": "4000", "dpmCollateral": "10000", "marginalYesPriceBps": 5500, "marginalNoPriceBps": 4500, "impliedYesProbabilityBps": 6000, "impliedNoProbabilityBps": 4000]
        case PolkamarktRuntimeContract.RPC.quoteBuy:
            result = ["marketId": 42, "outcome": "Yes", "collateralIn": "1000", "feeAmount": "5", "pricingCollateral": "995", "sharesOut": "2222"].merging(buyOverrides) { _, new in new }
        case PolkamarktRuntimeContract.RPC.quoteSell:
            result = ["marketId": 42, "outcome": "No", "sharesIn": "1000", "grossCollateralOut": "556", "feeAmount": "1", "collateralOut": "555"].merging(sellOverrides) { _, new in new }
        case PolkamarktRuntimeContract.RPC.claimable:
            result = claimMissing ? NSNull() : ["marketId": params[1], "account": claimOwner ?? owner, "status": "Open", "resolutionOutcome": NSNull(), "yesShares": yesShares, "noShares": noShares, "netCollateralPaid": "900", "traderPayout": "0", "claimablePayout": "0", "creatorFees": "0", "isCreator": false].merging(claimOverrides) { _, new in new }
        case SoraPassport.RPCMethod.freeBalance:
            result = ["balance": (params[1] as? String) == WalletAssetId.xor.rawValue ? xor : kusd]
        default: throw RuntimeScreenFailure.unexpected
        }
        return try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": object["id"]!, "result": result])
    }
}
private final class RuntimeScreenURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> Data)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let data = try Self.handler?(request) ?? { throw RuntimeScreenFailure.unexpected }()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed); client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private final class RuntimeScreenExtrinsics: ExtrinsicServiceProtocol {
    var rawFee = "7"
    var holdFee = false, heldFee: EstimateFeeClosure?, onFee: (() -> Void)?
    var failure: Error?
    var builders: [RuntimeScreenBuilder] = []
    var estimateCount = 0
    var prepareCount = 0
    var submitCount = 0
    var preparedSubmitCount = 0
    var cancelAfterPrepare = false
    var prepared: PreparedExtrinsicSubmission?
    let call = RuntimeScreenCall()
    private func record(_ closure: ExtrinsicBuilderClosure) throws {
        let builder = RuntimeScreenBuilder(); _ = try closure(builder); builders.append(builder)
        if let failure { throw failure }
    }
    func estimateFee(_ closure: @escaping ExtrinsicBuilderClosure, runningIn queue: DispatchQueue, completion: @escaping EstimateFeeClosure) {
        estimateCount += 1
        do { try record(closure); if holdFee { heldFee = completion; onFee?() } else { completion(.success(rawFee)) } } catch { completion(.failure(error)) }
    }
    func prepareAndEstimateFee(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
                               preSigningValidation: @escaping () throws -> Void, runningIn queue: DispatchQueue,
                               completion: @escaping (Result<PreparedExtrinsicFeeQualification, Error>) -> Void) -> CancellableCall {
        prepareCount += 1
        do {
            try preSigningValidation(); try record(closure)
            let bytes = Data([1, 2, 3, 4])
            let result = PreparedExtrinsicSubmission(data: bytes, hash: try bytes.blake2b32().toHex(includePrefix: true))
            prepared = result
            if cancelAfterPrepare { withUnsafeCurrentTask { $0?.cancel() } }
            completion(.success(PreparedExtrinsicFeeQualification(prepared: result, rawFee: rawFee)))
        } catch { completion(.failure(error)) }
        return call
    }
    func prepareAndEstimateFee(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
        lifecycleLease: WalletLifecycleLease?, runtimeValidation: ((RuntimeCoderFactoryProtocol) throws -> Void)?,
        finalizedHeadValidation: ((String) throws -> Void)?, preSigningValidation: @escaping () throws -> Void,
        runningIn queue: DispatchQueue, completion: @escaping (Result<PreparedExtrinsicFeeQualification, Error>) -> Void) -> CancellableCall {
        XCTFail("Unexpected lifecycle preparation"); completion(.failure(RuntimeScreenFailure.unexpected)); return call
    }
    func submit(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol, runningIn queue: DispatchQueue,
                completion: @escaping ExtrinsicSubmitClosure) {
        submitCount += 1
        do { try record(closure); completion(.success("0x" + String(repeating: "0a", count: 32)), "0x" + String(repeating: "0a", count: 32), nil) }
        catch { completion(.failure(error), nil, nil) }
    }
    func submit(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol, lifecycleLease: WalletLifecycleLease?,
                runningIn queue: DispatchQueue, completion: @escaping ExtrinsicSubmitClosure) {
        XCTFail("Unexpected lifecycle submission"); completion(.failure(RuntimeScreenFailure.unexpected), nil, nil)
    }
    func prepare(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol, runningIn queue: DispatchQueue,
                 completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void) {
        XCTFail("Unexpected unqualified preparation"); completion(.failure(RuntimeScreenFailure.unexpected))
    }
    func prepare(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol, lifecycleLease: WalletLifecycleLease?,
        runtimeValidation: ((RuntimeCoderFactoryProtocol) throws -> Void)?, preSigningValidation: (() throws -> Void)?,
        runningIn queue: DispatchQueue, completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void) {
        XCTFail("Unexpected lifecycle preparation"); completion(.failure(RuntimeScreenFailure.unexpected))
    }
    func submitPrepared(_ prepared: PreparedExtrinsicSubmission, retainingTransportWitness: Bool, expectedRawFee: String,
        preTransportValidation: @escaping () throws -> Void, runningIn queue: DispatchQueue,
        completion: @escaping (Result<String, Error>) -> Void) -> CancellableCall {
        preparedSubmitCount += 1; XCTFail("Unexpected transport"); completion(.failure(RuntimeScreenFailure.unexpected)); return call
    }
}
private final class RuntimeScreenBuilder: SoraPassport.ExtrinsicBuilderProtocol {
    var calls: [JSON] = []
    var atomicSelections: [Bool] = []
    func with<A: Codable>(address: A) throws -> Self { XCTFail("Unexpected address binding"); return self }
    func with(nonce: UInt32) -> Self { XCTFail("Unexpected nonce"); return self }
    func with(era: Era, blockHash: String) -> Self { XCTFail("Unexpected era"); return self }
    func with(tip: BigUInt) -> Self { XCTFail("Unexpected tip"); return self }
    func with(shouldUseAtomicBatch: Bool) -> Self { atomicSelections.append(shouldUseAtomicBatch); return self }
    func adding<T: RuntimeCallable>(call: T) throws -> Self { let encoded = try JSONEncoder.scaleCompatible().encode(SoraPassport.EncodingContainer(value: call)); calls.append(try JSONDecoder.scaleCompatible(snakeCase: false).decode(SoraPassport.JsonContainer.self, from: encoded).value); return self }
    func adding(rawCall: Data) throws -> Self { XCTFail("Unexpected raw call"); throw RuntimeScreenFailure.unexpected }
    func signing(by signer: (Data) throws -> Data, of type: SoraPassport.CryptoType, using encoder: DynamicScaleEncoding,
                 metadata: RuntimeMetadata) throws -> Self { XCTFail("Unexpected signing"); throw RuntimeScreenFailure.unexpected }
    func buildExtrinsic(metadata: RuntimeMetadata) throws -> Extrinsic { XCTFail("Unexpected extrinsic build"); throw RuntimeScreenFailure.unexpected }
    func build(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws -> Data { throw RuntimeScreenFailure.unexpected }
    func buildSignature(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws -> Data { throw RuntimeScreenFailure.unexpected }
}
private final class RuntimeScreenNoSigner: SigningWrapperProtocol {
    func sign(_ originalData: Data) throws -> IRSignatureProtocol { XCTFail("No signing is permitted in these factory tests"); throw RuntimeScreenFailure.unexpected }
}

private final class RuntimeScreenCall: CancellableCall { func cancel() {} }

private final class RuntimeScreenPrices: CoingeckoOperationFactoryProtocol {
    var requests = [[String]](), values = [SoraPassport.PriceData](), failure: Swift.Error?
    func fetchPriceOperation(for tokenIds: [String]) -> BaseOperation<[SoraPassport.PriceData]> {
        requests.append(tokenIds)
        return ClosureOperation { if let failure = self.failure { throw failure }; return self.values }
    }
}
private final class RuntimeScreenContacts: WalletContactOperationFactoryProtocol {
    var items = [ContactItem](), failure: Swift.Error?
    func saveByAddressOperation(_ address: String) -> CompoundOperationWrapper<Void> { XCTFail("Unexpected contact mutation"); return .init(targetOperation: ClosureOperation { () }) }
    func fetchContactsOperation() -> CompoundOperationWrapper<[ContactItem]> {
        .init(targetOperation: ClosureOperation { if let failure = self.failure { throw failure }; return self.items })
    }
}
private final class RuntimeScreenAssets: AssetManagerProtocol {
    static var networkAssets = [AssetInfo]()
    var items = [(WalletAssetId.xor, "XOR"), (.val, "VAL")].map { AssetInfo(id: $0.0.rawValue, symbol: $0.1, chainId: "", precision: 18, icon: nil, displayName: $0.1, visible: true) }
    func assetInfo(for identifier: String) -> AssetInfo? { items.first { $0.identifier == identifier } }
    func getAssetList() -> [AssetInfo]? { items }
    func updateAssetList(_ list: [AssetInfo]) { items = list }
    func saveAssetList(_ list: [AssetInfo]) { items = list }
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { UInt(items.count) }
    func setup(for accountSettings: SelectedWalletSettings) {}
}
private final class RuntimeScreenFarms: DemeterFarmingServiceProtocol {
    var failure: Swift.Error?, reads = [Data]()
    func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?) async -> [UserFarm] { [] }
    func loadUserFarmInfos(baseAssetId: String?, targetAssetId: String?, accountId: Data) async throws -> [UserFarm] { reads.append(accountId); if let failure { throw failure }; return [] }
    func getAllFarms() async throws -> [Farm] { [] }
    func getFarm(with id: String) -> Farm? { nil }
    func getFarmDetails(baseAssetId: String, poolAssetId: String, rewardAssetId: String) async throws -> [Farm] { [] }
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) { completion([]) }
}

private final class RuntimeScreenWeakController { weak var value: UIViewController?; init(_ value: UIViewController) { self.value = value } }

extension PolkamarktAccountScreenTests {
    private func claimableDetail(trader: String, creator: String, isCreator: Bool) async throws -> PolkamarktMarketViewController {
        fixture.server.market = fixture.markets["Resolved500"]!
        fixture.server.claimOverrides = ["status": "Resolved", "resolutionOutcome": "Yes", "traderPayout": trader,
            "claimablePayout": trader, "creatorFees": creator, "isCreator": isCreator]
        return try await interactiveDetail()
    }
    func testResolvedTraderClaimReviewsTheExactPayoutAndFinalizedCheckpoint() async throws {
        let d = try await claimableDetail(trader: "1234567890123456789", creator: "0", isCreator: false)
        d.presentClaims(); let a = try await alert(d)
        XCTAssertTrue(a.message?.contains("Trader payout · 1.234567 KUSD") == true)
        XCTAssertTrue(a.message?.contains(fixture.server.block) == true)
        XCTAssertEqual(a.actions.map(\.title), ["Claim trader payout", "Cancel"])
        XCTAssertEqual(fixture.extrinsics.prepareCount, 0)
    }
    func testResolvedCreatorFeesAreReviewedSeparatelyFromTheTraderPayout() async throws {
        let d = try await claimableDetail(trader: "2000000000000000000", creator: "3000000000000000000", isCreator: true)
        d.presentClaims(); let a = try await alert(d)
        XCTAssertTrue(a.message?.contains("Trader payout · 2 KUSD") == true)
        XCTAssertTrue(a.message?.contains("Creator fees · 3 KUSD") == true)
        XCTAssertEqual(a.actions.map(\.title), ["Claim trader payout", "Claim creator fees", "Cancel"])
        XCTAssertEqual(cell(d,1,2).accessoryType, .disclosureIndicator)
    }
    func testCreatorOnlyClaimDoesNotOfferAnEmptyTraderClaim() async throws {
        let d = try await claimableDetail(trader: "0", creator: "3000000000000000000", isCreator: true)
        d.tableView(d.tableView, didSelectRowAt: IndexPath(row: 2, section: 1)); let a = try await alert(d)
        XCTAssertEqual(a.actions.map(\.title), ["Claim creator fees", "Cancel"])
        XCTAssertFalse(a.message?.contains("Trader payout ·") == true)
    }
    func testNonCreatorCannotSeeAClaimActionForAnotherCreatorsFees() async throws {
        let d = try await claimableDetail(trader: "2000000000000000000", creator: "3000000000000000000", isCreator: false)
        d.presentClaims(); let a = try await alert(d)
        XCTAssertEqual(a.actions.map(\.title), ["Claim trader payout", "Cancel"])
        XCTAssertFalse(a.message?.contains("Creator fees ·") == true)
    }
    private func recordPending(action: String, market: UInt32 = 42, state: PolkamarktPendingState,
                               age: TimeInterval = 0, account: String? = nil) async throws {
        let store = try PolkamarktPendingStore(baseURL: fixture.directory), time = Date().addingTimeInterval(age)
        var value = PolkamarktPendingMutation(id: UUID(), account: account ?? fixture.account.address, action: action,
            marketIds: [market], createdAt: time, updatedAt: time, extrinsicHash: nil, state: .preparing, finalizedBlock: nil, errorClass: nil)
        try await store.put(value)
        if state == .failedBeforeSubmission { value.state = state; value.errorClass = "fixture_preparation_failed"; try await store.put(value); return }
        value.state = .signedBeforeTransport; value.extrinsicHash = "0x" + String(repeating: "cd", count: 32); try await store.put(value)
        value.state = .submitted; try await store.put(value)
        value.state = state; value.finalizedBlock = 399; try await store.put(value)
    }
    func testDetailDisplaysDurableTerminalStatesNewestFirstWithoutRestartingSubmission() async throws {
        try await recordPending(action: "buy", state: .failedBeforeSubmission, age: -60)
        try await recordPending(action: "sell", state: .finalized)
        let d = try await interactiveDetail(); await wait { d.tableView.numberOfRows(inSection: 3) == 2 }
        XCTAssertEqual(cell(d,3,0).textLabel?.text, "sell"); XCTAssertEqual(cell(d,3,0).detailTextLabel?.text, "finalized")
        XCTAssertEqual(cell(d,3,1).detailTextLabel?.text, "failedBeforeSubmission")
        XCTAssertEqual(cell(d,3,0).selectionStyle, .none); XCTAssertNil(d.navigationItem.prompt)
        XCTAssertEqual(fixture.extrinsics.preparedSubmitCount, 0)
    }
    func testDetailDoesNotDisplayAnotherWalletsOrAnotherMarketsTerminalMutation() async throws {
        try await recordPending(action: "buy", market: 43, state: .failedBeforeSubmission)
        try await recordPending(action: "sell", state: .failedBeforeSubmission, account: "other-wallet")
        let d = try await interactiveDetail(); await wait { d.refreshControl?.isRefreshing != true }
        XCTAssertEqual(cell(d,3).textLabel?.text, "No pending transaction")
    }
    func testRejectedTerminalMutationIsVisibleWithoutEnablingRowSelection() async throws {
        try await recordPending(action: "buy", state: .rejected)
        let d = try await interactiveDetail(); await wait { self.cell(d,3).textLabel?.text == "buy" }
        XCTAssertEqual(cell(d,3).detailTextLabel?.text, "rejected"); XCTAssertEqual(cell(d,3).selectionStyle, .none)
    }
    func testCorruptPendingJournalShowsRecoveryRequiredAndDisablesTrading() async throws {
        let journal = fixture.directory.appendingPathComponent("SORA/PendingTransactions/polkamarkt-v1.json")
        try Data("invalid journal".utf8).write(to: journal)
        let d = try await interactiveDetail()
        await wait { self.cell(d,3).textLabel?.text == "Recovery required" }
        XCTAssertFalse(d.navigationItem.rightBarButtonItem?.isEnabled ?? true)
        XCTAssertTrue(cell(d,3).detailTextLabel?.text?.contains("protected pending-transaction journal") == true)
    }
    func testTradeForAnotherAccountNeverStartsPreparationOrPresentsAResult() async throws {
        let d = try await interactiveDetail(), quote = try await fixture.quote(input: BigUInt("1000000000000000000"))
        d.submitTrade(PolkamarktTradeRequest(account: "another-account", marketId: 42, outcome: .yes, side: .buy,
            input: quote.input, minimumOutput: quote.minimumOutput, confirmedCloseBlock: quote.closeBlock,
            confirmedMarketFee: quote.marketFee, maximumNetworkFee: quote.networkFee))
        XCTAssertNil(d.presentedViewController); XCTAssertEqual(fixture.extrinsics.prepareCount, 0)
    }
}

extension PolkamarktAccountScreenTests {
    private func reviewedCatalog(allowed: @escaping () -> Bool = { true }, coordinatorAvailable: Bool = true,
                                 storeFailure: Bool = false) async -> PolkamarktViewController {
        server.positionCount = 2
        fixture.server.claimOverrides = ["status": "Resolved", "resolutionOutcome": "Yes", "traderPayout": "2000000000000000000", "claimablePayout": "2000000000000000000"]
        let client = PIIndexerClient(session: session, historyShapeMemory: PIHistoryShapeMemory(), cacheDirectory: directory, retryPause: { _ in })
        let f = fixture!
        let c = PolkamarktViewController(walletContext: f.context, client: client,
            pendingStore: { if storeFailure { throw RuntimeScreenFailure.offline }; return try PolkamarktPendingStore(baseURL: f.directory) },
            coordinator: { _ in coordinatorAvailable ? f.subject : nil }, mutationsAllowed: allowed)
        navigation = UINavigationController(rootViewController: c); window.rootViewController = navigation; window.makeKeyAndVisible(); c.loadViewIfNeeded()
        await wait { c.tableView.numberOfRows(inSection: 1) == 2 && c.refreshControl?.isRefreshing != true }
        // Positions are assigned before the authoritative review completes; allow that bounded local read to settle.
        if allowed() && coordinatorAvailable && !storeFailure && !f.server.claimMissing {
            await wait { c.navigationItem.rightBarButtonItems?.contains { $0.title == "Claim" } == true }
        }
        return c
    }
    private func openBatchReview(_ c: PolkamarktViewController) async throws -> UIAlertController {
        let item = try XCTUnwrap(c.navigationItem.rightBarButtonItems?.first { $0.title == "Claim" })
        _ = c.perform(try XCTUnwrap(item.action))
        await wait { c.presentedViewController is UIAlertController }
        return try XCTUnwrap(c.presentedViewController as? UIAlertController)
    }
    func testCatalogReviewsEveryClaimAtOneFinalizedCheckpointBeforeSigning() async throws {
        let c = await reviewedCatalog(), alert = try await openBatchReview(c)
        XCTAssertTrue(alert.message?.contains("Market 42 · 2 KUSD") == true)
        XCTAssertTrue(alert.message?.contains("Market 43 · 2 KUSD") == true)
        XCTAssertTrue(alert.message?.contains(fixture.server.block) == true)
        XCTAssertEqual(alert.actions.map(\.title), ["Cancel", "Review and sign"])
        XCTAssertEqual(alert.actions.last?.style, .destructive); XCTAssertEqual(fixture.extrinsics.prepareCount, 0)
    }
    func testCatalogWithoutMutationAdmissionRetainsReadOnlyPositions() async {
        let c = await reviewedCatalog(allowed: { false })
        XCTAssertEqual(c.navigationItem.rightBarButtonItems?.map(\.title), ["Filters"])
        XCTAssertEqual(c.tableView.numberOfRows(inSection: 1), 2)
        _ = c.perform(NSSelectorFromString("presentBatchClaim")); XCTAssertNil(c.presentedViewController)
    }
    func testCatalogCannotReviewClaimsWithoutACoordinator() async {
        let c = await reviewedCatalog(coordinatorAvailable: false)
        XCTAssertEqual(c.navigationItem.rightBarButtonItems?.map(\.title), ["Filters"])
        XCTAssertEqual(fixture.extrinsics.prepareCount, 0)
    }
    func testUnreadableCatalogJournalKeepsClaimControlsUnavailable() async {
        let c = await reviewedCatalog(storeFailure: true)
        XCTAssertEqual(c.navigationItem.rightBarButtonItems?.map(\.title), ["Filters"])
        XCTAssertEqual(c.tableView.numberOfRows(inSection: 1), 2)
    }
    func testMissingAuthoritativeClaimablesNeverEnableCatalogClaims() async {
        fixture.server.claimMissing = true
        let c = await reviewedCatalog()
        XCTAssertEqual(c.navigationItem.rightBarButtonItems?.map(\.title), ["Filters"])
    }
    func testCatalogClaimReviewRechecksMutationAdmissionAtTheTap() async throws {
        var enabled = true; let c = await reviewedCatalog(allowed: { enabled })
        let item = try XCTUnwrap(c.navigationItem.rightBarButtonItems?.first { $0.title == "Claim" })
        enabled = false; _ = c.perform(try XCTUnwrap(item.action))
        XCTAssertNil(c.presentedViewController); XCTAssertEqual(fixture.extrinsics.prepareCount, 0)
    }
    func testCatalogClaimReviewCannotUseThePreviousSelectedWallet() async throws {
        let c = await reviewedCatalog(), item = try XCTUnwrap(c.navigationItem.rightBarButtonItems?.first { $0.title == "Claim" })
        SelectedWalletSettings.shared.commitInternalValue(nil); _ = c.perform(try XCTUnwrap(item.action))
        XCTAssertNil(c.presentedViewController); XCTAssertEqual(content(c, 1)?.text, "Connect a SORA2 wallet to see positions")
    }
    func testCatalogRefreshReplacesTheReviewedPayoutBeforeAnotherClaim() async throws {
        let c = await reviewedCatalog()
        fixture.server.claimOverrides["traderPayout"] = "3000000000000000000"
        fixture.server.claimOverrides["claimablePayout"] = "3000000000000000000"
        c.refreshControl?.sendActions(for: .valueChanged)
        await wait { c.navigationItem.rightBarButtonItems?.contains { $0.title == "Claim" } == true }
        let a = try await openBatchReview(c); XCTAssertTrue(a.message?.contains("Market 42 · 3 KUSD") == true)
    }
    func testScopedCatalogOpensDetailsUsingTheSameLocalCoordinator() async throws {
        let c = await reviewedCatalog()
        c.tableView(c.tableView, didSelectRowAt: IndexPath(row: 0, section: 1))
        await wait { self.navigation.topViewController !== c }
        let d = try XCTUnwrap(navigation.topViewController as? PolkamarktMarketViewController)
        await wait { d.tableView(d.tableView, numberOfRowsInSection: 1) == 3 }
        XCTAssertEqual(cell(d, 1, 2).textLabel?.text, "Claimable")
        XCTAssertTrue(cell(d, 1, 2).detailTextLabel?.text?.contains("2") == true)
    }
    func testCatalogMenuCanSelectAndClearCategoryFilters() async throws {
        let c = await reviewedCatalog(allowed: { false })
        let menu = try XCTUnwrap(c.navigationItem.rightBarButtonItems?.first?.menu)
        let categories = try XCTUnwrap(menu.children.last as? UIMenu)
        let category = try XCTUnwrap(categories.children.compactMap { $0 as? UIAction }.last)
        let button = UIButton(); button.addAction(category, for: .touchUpInside); button.sendActions(for: .touchUpInside)
        await wait { c.tableView.numberOfRows(inSection: 2) == 0 }
        let current = try XCTUnwrap(c.navigationItem.rightBarButtonItems?.first?.menu?.children.last as? UIMenu)
        XCTAssertEqual(current.title, category.title)
        let all = try XCTUnwrap(current.children.first as? UIAction), reset = UIButton()
        reset.addAction(all, for: .touchUpInside); reset.sendActions(for: .touchUpInside)
        await wait { c.tableView.numberOfRows(inSection: 2) == 1 }
    }
    func testCatalogMineFilterReflectsTheSelectedWalletAndCanBeCleared() async throws {
        let c = await reviewedCatalog(allowed: { false })
        let action = try XCTUnwrap(c.navigationItem.rightBarButtonItems?.first?.menu?.children.first as? UIAction)
        let button = UIButton(); button.addAction(action, for: .touchUpInside); button.sendActions(for: .touchUpInside)
        await wait { c.tableView.numberOfRows(inSection: 2) == 0 }
        let selected = try XCTUnwrap(c.navigationItem.rightBarButtonItems?.first?.menu?.children.first as? UIAction)
        XCTAssertEqual(selected.state, .on)
        let reset = UIButton(); reset.addAction(selected, for: .touchUpInside); reset.sendActions(for: .touchUpInside)
        await wait { c.tableView.numberOfRows(inSection: 2) == 1 }
    }
}

extension PolkamarktAccountScreenTests {
    private func reviewedBatchAuthorization() async throws -> PolkamarktClaimAuthorization {
        let review = try await fixture.subject.authoritativeClaimables(account: fixture.account.address, marketIds: [42, 43])
        return try PolkamarktClaimValidator.reviewedTraderAuthorization(claims: review.claims, account: review.account,
            source: .reviewedPositions, finalizedBlockHash: review.finalizedBlockHash)
    }
    func testCatalogClaimSubmissionReportsAnUnavailableCoordinatorWithoutSigning() async throws {
        let c = await reviewedCatalog(coordinatorAvailable: false), authorization = try await reviewedBatchAuthorization()
        c.submitBatchClaim(authorization: authorization)
        await wait { c.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(c.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "Claims not completed"); XCTAssertEqual(fixture.extrinsics.prepareCount, 0)
    }
    func testCatalogClaimSubmissionReportsJournalFailureWithoutSigning() async throws {
        let c = await reviewedCatalog(storeFailure: true), authorization = try await reviewedBatchAuthorization()
        c.submitBatchClaim(authorization: authorization)
        await wait { c.presentedViewController is UIAlertController }
        XCTAssertEqual((c.presentedViewController as? UIAlertController)?.title, "Claims not completed")
        XCTAssertEqual(fixture.extrinsics.prepareCount, 0)
    }
    func testCatalogClaimSubmissionRejectsAStaleAccountBeforeOpeningTheJournal() async throws {
        let c = await reviewedCatalog(), authorization = try await reviewedBatchAuthorization()
        SelectedWalletSettings.shared.commitInternalValue(nil); c.submitBatchClaim(authorization: authorization)
        XCTAssertNil(c.presentedViewController); XCTAssertEqual(fixture.extrinsics.prepareCount, 0)
    }
    func testCatalogDoesNotSubmitAReviewedClaimAfterItsViewIsDetached() async throws {
        let c = await reviewedCatalog(), authorization = try await reviewedBatchAuthorization()
        window.rootViewController = nil; c.submitBatchClaim(authorization: authorization)
        XCTAssertNil(c.presentedViewController); XCTAssertEqual(fixture.extrinsics.prepareCount, 0)
    }
    func testOpeningACatalogMarketReportsJournalFailureInsteadOfShowingAnUnsafeDetail() async {
        let c = await reviewedCatalog(storeFailure: true)
        c.tableView(c.tableView, didSelectRowAt: IndexPath(row: 0, section: 2))
        await wait { c.presentedViewController is UIAlertController }
        XCTAssertEqual((c.presentedViewController as? UIAlertController)?.title, "Market unavailable")
        XCTAssertTrue(navigation.topViewController === c)
    }
}
