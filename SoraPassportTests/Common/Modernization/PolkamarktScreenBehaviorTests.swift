// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraFoundation
import SoraKeystore
import UIKit
import XCTest
@testable import SoraPassport

/// Exercises the actual catalog and detail screens through their public UIKit
/// lifecycle and data-source contracts. Every HTTP request is intercepted by
/// the local URLProtocol fixture; no runtime signer is installed.
@MainActor
final class PolkamarktScreenBehaviorTests: XCTestCase {
    private var previousWindow: UIWindow?
    private var previousLanguage = "en"
    private var window: UIWindow!
    private var navigation: UINavigationController!
    private var previousAccount: AccountItem?
    private var featureEnabled = false
    private var animationsEnabled = true
    private var session: URLSession!
    private var directory: URL!
    private let server = MarketScreenServer()

    override func setUp() {
        super.setUp()
        previousLanguage = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "en"
        previousAccount = SelectedWalletSettings.shared.currentAccount
        SelectedWalletSettings.shared.commitInternalValue(nil)
        featureEnabled = SettingsManager.shared.polkamarktEnabled
        SettingsManager.shared.polkamarktEnabled = true
        animationsEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        server.reset()
        PIStubIndexerProtocol.install { [server] in server.respond($0) }
        session = PIStubIndexerProtocol.session()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        previousWindow = scene?.windows.first { $0.isKeyWindow }
        window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
        window.frame = scene?.coordinateSpace.bounds ?? UIScreen.main.bounds
    }

    override func tearDown() {
        navigation?.popToRootViewController(animated: false)
        window?.isHidden = true
        window?.rootViewController = nil
        navigation = nil
        window = nil
        session.invalidateAndCancel()
        session = nil
        PIStubIndexerProtocol.uninstall()
        try? FileManager.default.removeItem(at: directory)
        SelectedWalletSettings.shared.commitInternalValue(previousAccount)
        SettingsManager.shared.polkamarktEnabled = featureEnabled
        UIView.setAnimationsEnabled(animationsEnabled)
        previousWindow?.makeKeyAndVisible()
        LocalizationManager.shared.selectedLocalization = previousLanguage
        super.tearDown()
    }

    private func openCatalog() async throws -> PolkamarktViewController {
        let client = PIIndexerClient(session: session, historyShapeMemory: PIHistoryShapeMemory(),
                                     cacheDirectory: directory, retryPause: { _ in })
        let controller = PolkamarktViewController(walletContext: WalletContextMock(), client: client)
        navigation = UINavigationController(rootViewController: controller)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        window.layoutIfNeeded()
        await waitUntil { PIStubIndexerProtocol.requests.contains("MobilePolkamarktMarkets") }
        return controller
    }

    private func waitUntil(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Screen did not finish the fixture response", file: file, line: line)
    }

    private func waitForCatalog(_ controller: PolkamarktViewController) async {
        await waitUntil { controller.tableView.numberOfRows(inSection: 2) == 2 }
    }

    private func configuration(_ controller: UITableViewController, section: Int, row: Int = 0) -> UIListContentConfiguration? {
        guard row < controller.tableView(controller.tableView, numberOfRowsInSection: section) else { return nil }
        return controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: row, section: section))
            .contentConfiguration as? UIListContentConfiguration
    }

    private func search(_ text: String, scope: Int, in controller: PolkamarktViewController) throws {
        let search = try XCTUnwrap(controller.navigationItem.searchController)
        search.searchBar.text = text
        search.searchBar.selectedScopeButtonIndex = scope
        controller.updateSearchResults(for: search)
    }

    private func openDetail(_ controller: PolkamarktViewController, row: Int = 0) async throws -> UITableViewController {
        _ = try XCTUnwrap(row < controller.tableView.numberOfRows(inSection: 2) ? controller : nil)
        controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: row, section: 2))
        await waitUntil { self.navigation.topViewController !== controller }
        let detail = try XCTUnwrap(navigation.topViewController as? UITableViewController)
        await waitUntil { detail.tableView.tableHeaderView is PolkamarktLineChartView }
        return detail
    }

    func testCatalogRendersSortedActiveMarketsAndReadOnlyPositionState() async throws {
        let controller = try await openCatalog()
        await waitForCatalog(controller)
        XCTAssertEqual(controller.numberOfSections(in: controller.tableView), 3)
        XCTAssertEqual(configuration(controller, section: 2)?.text, "Will the championship finish on Sunday?")
        XCTAssertEqual(configuration(controller, section: 2, row: 1)?.text, "Will the network upgrade ship?")
        XCTAssertTrue(configuration(controller, section: 2)?.secondaryText?.contains("45%") == true)
        XCTAssertTrue(configuration(controller, section: 2, row: 1)?.secondaryText?.contains("65%") == true)
        XCTAssertEqual(configuration(controller, section: 1)?.text, "Connect a SORA2 wallet to see positions")
        XCTAssertTrue(configuration(controller, section: 0)?.secondaryText?.contains("2.5M") == true)
        XCTAssertTrue(configuration(controller, section: 0)?.secondaryText?.contains("12.5K") == true)
        XCTAssertEqual(controller.navigationItem.rightBarButtonItems?.map(\.title), ["Filters"])
        XCTAssertFalse(PIStubIndexerProtocol.requests.contains("MobilePolkamarktPositions"))
        XCTAssertEqual(controller.tableView(controller.tableView, numberOfRowsInSection: 99), 0)
        XCTAssertNil(controller.tableView(controller.tableView, titleForHeaderInSection: 99))
    }

    func testSearchMatchesMetadataCaseInsensitivelyAndCombinesWithStatusScope() async throws {
        let controller = try await openCatalog()
        await waitForCatalog(controller)
        for query in ["  UPGRADE  ", "crypto", "governance", "release milestone", "creator-a"] {
            try search(query, scope: 0, in: controller)
            XCTAssertEqual(controller.tableView.numberOfRows(inSection: 2), 1, query)
            XCTAssertEqual(configuration(controller, section: 2)?.text, "Will the network upgrade ship?")
        }
        try search("upgrade", scope: 1, in: controller)
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 2), 0)
        try search("", scope: 1, in: controller)
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 2), 1)
        XCTAssertEqual(configuration(controller, section: 2)?.text, "Was the experiment successful?")
        try search("", scope: 2, in: controller)
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 2), 3)
        try search("no matching market", scope: 2, in: controller)
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 2), 0)
    }

    func testCatalogRemainsUsableWhenActivitySignalsFail() async throws {
        server.failedOperations = ["MobilePolkamarktSignals"]
        let controller = try await openCatalog()
        await waitForCatalog(controller)
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), 0)
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 2), 2)
        XCTAssertNil(controller.presentedViewController)
    }

    func testInitialCatalogFailurePresentsErrorWithoutInventingRows() async throws {
        server.failedOperations = ["MobilePolkamarktMarkets"]
        let controller = try await openCatalog()
        await waitUntil { controller.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "Markets unavailable")
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 2), 0)
        XCTAssertFalse(controller.refreshControl?.isRefreshing ?? true)
    }

    func testRefreshFallsBackToCachedCatalogAndLabelsItsProvenance() async throws {
        let controller = try await openCatalog()
        await waitForCatalog(controller)
        server.failedOperations = ["MobilePolkamarktMarkets", "MobilePolkamarktSignals"]
        controller.refreshControl?.sendActions(for: .valueChanged)
        await waitUntil { controller.navigationItem.prompt?.contains("Offline PI snapshot") == true }
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 2), 2)
        XCTAssertTrue(controller.tableView(controller.tableView, titleForFooterInSection: 2)?.contains("Offline PI snapshot") == true)
        XCTAssertFalse(controller.refreshControl?.isRefreshing ?? true)
    }

    func testDetailShowsIndexedValuesButDoesNotClaimTheyAreFinalizedRuntimeState() async throws {
        let controller = try await openCatalog()
        await waitForCatalog(controller)
        let detail = try await openDetail(controller, row: 1)
        XCTAssertEqual(detail.title, "Will the network upgrade ship?")
        XCTAssertEqual(detail.numberOfSections(in: detail.tableView), 5)
        XCTAssertEqual(detail.tableView(detail.tableView, numberOfRowsInSection: 0), 6)
        let cells = (0..<6).map { detail.tableView(detail.tableView, cellForRowAt: IndexPath(row: $0, section: 0)) }
        XCTAssertEqual(cells[0].detailTextLabel?.text, "—")
        XCTAssertEqual(cells[3].detailTextLabel?.text, "123.45")
        XCTAssertEqual(cells[4].detailTextLabel?.text, "456.78")
        XCTAssertFalse(detail.navigationItem.rightBarButtonItem?.isEnabled ?? true)
        XCTAssertEqual(detail.tableView(detail.tableView, cellForRowAt: IndexPath(row: 0, section: 1)).textLabel?.text,
                       "Connect a SORA2 wallet to see positions")
        XCTAssertEqual(detail.tableView(detail.tableView, cellForRowAt: IndexPath(row: 0, section: 2)).textLabel?.text, "No indexed trades")
        XCTAssertEqual(detail.tableView(detail.tableView, cellForRowAt: IndexPath(row: 0, section: 3)).textLabel?.text, "No pending transaction")
        XCTAssertEqual(detail.tableView(detail.tableView, numberOfRowsInSection: 4), 2)
        XCTAssertEqual(detail.tableView(detail.tableView, cellForRowAt: IndexPath(row: 0, section: 4)).textLabel?.text, "Rules")
        XCTAssertEqual(detail.tableView(detail.tableView, cellForRowAt: IndexPath(row: 1, section: 4)).textLabel?.text, "Resolution source")
        for section in 0..<5 { XCTAssertNotNil(detail.tableView(detail.tableView, titleForHeaderInSection: section)) }
        XCTAssertEqual(detail.tableView(detail.tableView, titleForFooterInSection: 0), "Release milestone for governance")
        let chart = try XCTUnwrap(detail.tableView.tableHeaderView as? PolkamarktLineChartView)
        XCTAssertEqual(chart.values, [0.2, 0.65])
        XCTAssertTrue(chart.context.contains("oldest to newest"))
        detail.view.frame.size.width = 768
        detail.view.setNeedsLayout()
        detail.view.layoutIfNeeded()
        XCTAssertEqual(chart.frame.width, detail.tableView.bounds.width)
        XCTAssertFalse(PIStubIndexerProtocol.requests.contains("MobilePolkamarktTrades"))
    }

    func testDPMDetailShowsBothPricingCurvesAndIndexedMarker() async throws {
        let controller = try await openCatalog()
        await waitForCatalog(controller)
        let detail = try await openDetail(controller)
        let chart = try XCTUnwrap(detail.tableView.tableHeaderView as? PolkamarktLineChartView)
        XCTAssertEqual(chart.values.count, PolkamarktRuntimeContract.dpmCurvePointCount)
        XCTAssertEqual(chart.secondaryValues.count, chart.values.count)
        XCTAssertEqual(chart.markerFraction, 0.45)
        XCTAssertTrue(chart.caption.contains("Indexed DPM"))
        XCTAssertTrue(chart.context.contains("not a history chart"))
        XCTAssertEqual(chart.values.first!, chart.secondaryValues.last!, accuracy: 0.000001)
        XCTAssertEqual(chart.values.last!, chart.secondaryValues.first!, accuracy: 0.000001)
        XCTAssertFalse(detail.navigationItem.rightBarButtonItem?.isEnabled ?? true)
    }

    func testSnapshotFailureKeepsDetailVisibleWithUnavailableHistory() async throws {
        server.failedOperations = ["MobilePolkamarktSnapshots"]
        let controller = try await openCatalog()
        await waitForCatalog(controller)
        let detail = try await openDetail(controller, row: 1)
        let chart = try XCTUnwrap(detail.tableView.tableHeaderView as? PolkamarktLineChartView)
        XCTAssertTrue(chart.values.isEmpty)
        XCTAssertEqual(chart.caption, "Indexed probability history is unavailable.")
        XCTAssertFalse(detail.navigationItem.rightBarButtonItem?.isEnabled ?? true)
    }

    func testDisablingFeatureReturnsDetailToCatalog() async throws {
        let controller = try await openCatalog()
        await waitForCatalog(controller)
        let detail = try await openDetail(controller)
        SettingsManager.shared.polkamarktEnabled = false
        detail.beginAppearanceTransition(true, animated: false)
        detail.endAppearanceTransition()
        XCTAssertFalse(navigation.viewControllers.contains(where: { $0 === detail }))
    }
}

private final class MarketScreenServer {
    private let lock = NSLock()
    private var failures: Set<String> = []
    private var indexedAt = Int(Date().timeIntervalSince1970) - 2
    var failedOperations: Set<String> {
        get { lock.lock(); defer { lock.unlock() }; return failures }
        set { lock.lock(); failures = newValue; lock.unlock() }
    }
    func reset() { failedOperations = []; indexedAt = Int(Date().timeIntervalSince1970) - 2 }
    func respond(_ request: PIStubIndexerProtocol.Request) -> PIStubIndexerProtocol.Response {
        if failedOperations.contains(request.operation) { return .init(status: 503, body: "{}") }
        switch request.operation {
        case "MobileHealth":
            return .init(body: PIAdvancingIndexer.health(indexed: 1_000, finalized: 1_001, indexedAt: indexedAt))
        case "MobilePolkamarktMarkets":
            return .init(body: connection("markets", rows: [
                market(1, title: "Will the network upgrade ship?", category: "Crypto", status: "open", timestamp: 100,
                       extra: #", "tags":"governance", "description":"Release milestone for governance", "creator":"creator-a", "probability":"65", "rulesUri":"https://example.test/rules", "resolutionSource":"https://example.test/source", "resolutionEvidenceUri":"http://example.test/unsafe", "governanceUrl":"https://user:password@example.test/unsafe""#),
                market(2, title: "Will the championship finish on Sunday?", category: "Sports", status: "active", timestamp: 200,
                       extra: #", "mechanism":"dynamic_parimutuel", "priceYes":"0.45", "marginalYesPriceBps":4500"#),
                market(3, title: "Was the experiment successful?", category: "Science", status: "resolved", timestamp: 300, extra: "")
            ]))
        case "MobilePolkamarktSignals":
            return .init(body: #"{"data":{"polkamarktSignals":{"totalVolumeUsd":"2500000","activeMarkets":2,"activeAccounts":17,"liquidityUsd":"12500","liquiditySeries":[],"answerBreakdown":[],"accuracySummary":{"accuracyPercent":75}}}}"#)
        case "MobilePolkamarktSnapshots":
            let filter = request.variables["filter"] as? [String: Any]
            let condition = filter?["marketId"] as? [String: Any]
            let marketID = condition?["equalTo"] as? Int ?? 1
            return .init(body: connection("marketSnapshots", rows: [
                #"{"id":"snapshot-1","marketId":\#(marketID),"timestamp":100,"blockHeight":900,"type":"DEFAULT","priceYes":"0.2"}"#,
                #"{"id":"snapshot-2","marketId":\#(marketID),"timestamp":200,"blockHeight":901,"type":"DEFAULT","probability":"65"}"#
            ]))
        default: return .init(status: 400, body: "{}")
        }
    }
    private func market(_ id: Int, title: String, category: String, status: String, timestamp: Int, extra: String) -> String {
        #"{"id":"market-\#(id)","marketId":\#(id),"title":"\#(title)","category":"\#(category)","status":"\#(status)","timestamp":\#(timestamp),"updatedAtBlock":900,"liquidityUSD":"123.45","volumeUSD":"456.78"\#(extra)}"#
    }
    private func connection(_ name: String, rows: [String]) -> String {
        let edges = rows.enumerated().map { #"{"cursor":"c\#($0.offset)","node":\#($0.element)}"# }.joined(separator: ",")
        return #"{"data":{"\#(name)":{"edges":[\#(edges)],"pageInfo":{"hasNextPage":false,"hasPreviousPage":false,"startCursor":"c0","endCursor":"c\#(max(0, rows.count - 1))"},"totalCount":\#(rows.count)}}}"#
    }
}
