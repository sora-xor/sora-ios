// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraFoundation
import SoraKeystore
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class NexusScreenBehaviorTests: XCTestCase {
    private var previousWindow: UIWindow?
    private var previousLanguage = "en"
    private var window: UIWindow!
    private var navigation: UINavigationController!
    private var previousAccount: AccountItem?
    private var oldNexus = false
    private var oldTaira = false
    private var oldAnimations = true
    private var reader: NexusScreenReader!
    private var selected: AccountItem!

    override func setUp() {
        super.setUp()
        previousLanguage = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "en"
        previousAccount = SelectedWalletSettings.shared.currentAccount
        oldNexus = SettingsManager.shared.nexusEnabled
        oldTaira = SettingsManager.shared.isTairaEnabled
        oldAnimations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        SettingsManager.shared.nexusEnabled = true
        SettingsManager.shared.isTairaEnabled = true
        selected = AccountItem(address: "network-screen-fixture", cryptoType: .sr25519, networkType: 69,
            username: "Network screen fixture", publicKeyData: Data(repeating: 1, count: 32),
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        SelectedWalletSettings.shared.commitInternalValue(selected)
        reader = NexusScreenReader()
        navigation = UINavigationController(rootViewController: UIViewController())
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        previousWindow = scene?.windows.first { $0.isKeyWindow }
        window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
        window.frame = scene?.coordinateSpace.bounds ?? UIScreen.main.bounds
        window.rootViewController = navigation
        window.makeKeyAndVisible()
    }
    override func tearDown() {
        navigation.popToRootViewController(animated: false)
        window.isHidden = true
        window.rootViewController = nil
        window = nil
        navigation = nil
        SelectedWalletSettings.shared.commitInternalValue(previousAccount)
        SettingsManager.shared.nexusEnabled = oldNexus
        SettingsManager.shared.isTairaEnabled = oldTaira
        UIView.setAnimationsEnabled(oldAnimations)
        previousWindow?.makeKeyAndVisible()
        LocalizationManager.shared.selectedLocalization = previousLanguage
        super.tearDown()
    }
    private func account(_ configuration: NexusNetworkConfiguration) throws -> NetworkAccount {
        NetworkAccount(walletId: selected.address, networkId: configuration.networkId, derivationVersion: 1,
            publicKey: Data(repeating: 3, count: 32),
            address: try IrohaAddressCodec.encode(publicKeyHex: String(repeating: "03", count: 32),
                                                 chainDiscriminant: configuration.i105Discriminant))
    }
    private func open(_ configuration: NexusNetworkConfiguration? = nil) throws -> NexusNetworkDetailViewController {
        let configuration = try configuration ?? XCTUnwrap(NexusNetworkConfiguration.taira)
        let account = try account(configuration)
        reader.account = account.address
        let controller = NexusNetworkDetailViewController(account: account, configuration: configuration,
            coordinator: nil, readClient: reader, mutationUnavailableReason: "Fixture journal unavailable")
        navigation.pushViewController(controller, animated: false)
        controller.loadViewIfNeeded()
        window.layoutIfNeeded()
        return controller
    }
    private func content(_ controller: NexusNetworkDetailViewController, section: Int, row: Int = 0) -> UIListContentConfiguration? {
        controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: row, section: section)).contentConfiguration as? UIListContentConfiguration
    }
    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Fixture screen did not settle", file: file, line: line)
    }
    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) }
    }

    func testProductionAddressScreenIsExplicitlyOfflineAndCopiesOnlyItsAddress() throws {
        let controller = try open(.minamoto)
        XCTAssertEqual(content(controller, section: 0)?.text, "Coming soon")
        XCTAssertNil(controller.navigationItem.rightBarButtonItem)
        XCTAssertEqual(reader.balanceReads, 0)
        XCTAssertTrue(reader.historyCursors.isEmpty)
        XCTAssertTrue(controller.tableView(controller.tableView, titleForFooterInSection: 0)?.contains("production address is ready") == true)
        let images = views(UIImageView.self, in: try XCTUnwrap(controller.tableView.tableHeaderView))
        XCTAssertTrue(images.contains { $0.image != nil })
        let copy = try XCTUnwrap(views(UIButton.self, in: controller.view).first { $0.currentTitle == "Copy address" })
        let clipboard = UIPasteboard.general.items
        defer { UIPasteboard.general.items = clipboard }
        copy.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, reader.account)
        XCTAssertFalse(views(UIButton.self, in: controller.view).contains { $0.accessibilityIdentifier == "taira.faucet.request" })
        XCTAssertTrue(views(UIButton.self, in: controller.view).first { $0.currentTitle == "Open explorer" }?.isHidden == true)
    }

    func testTairaReadOnlyScreenShowsExactBalanceHistoryAndJournalRecovery() async throws {
        let controller = try open()
        await waitUntil { self.content(controller, section: 0)?.text == "12.500000001 XOR" }
        await waitUntil { controller.tableView.numberOfRows(inSection: 2) == 2 }
        XCTAssertNil(controller.navigationItem.rightBarButtonItem)
        XCTAssertEqual(content(controller, section: 1)?.text, "Recovery required")
        XCTAssertTrue(content(controller, section: 2)?.text?.hasPrefix("Sent 1.25 XOR") == true)
        XCTAssertTrue(content(controller, section: 2, row: 1)?.text?.hasPrefix("Received 2.5 XOR") == true)
        XCTAssertEqual(reader.historyCursors.count, 1)
        XCTAssertNil(try XCTUnwrap(reader.historyCursors.first))
        for section in 0..<3 { XCTAssertNotNil(controller.tableView(controller.tableView, titleForHeaderInSection: section)) }
        controller.view.frame.size.width = 768
        controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
        XCTAssertEqual(controller.tableView.tableHeaderView?.frame.width, controller.tableView.bounds.width)
        controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: 0, section: 2))
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "Transfer completed")
        XCTAssertTrue(alert.message?.contains("first-transaction") == true)
    }

    func testUnavailableBalanceCannotBeShownAsZeroOrUsedToRequestHistory() async throws {
        reader.balanceFailure = true
        let controller = try open()
        await waitUntil { self.content(controller, section: 0)?.text == "Unavailable XOR" }
        XCTAssertEqual(content(controller, section: 2)?.text, "History unavailable")
        XCTAssertTrue(reader.historyCursors.isEmpty)
        XCTAssertNil(controller.navigationItem.rightBarButtonItem)
    }

    func testUnavailableHistoryKeepsBalanceAndOffersReadOnlyRefresh() async throws {
        reader.historyFailures = 1
        let controller = try open()
        await waitUntil { self.content(controller, section: 2)?.text == "History unavailable" }
        XCTAssertEqual(content(controller, section: 0)?.text, "12.500000001 XOR")
        controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: 0, section: 2))
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "Check connection")
        XCTAssertEqual(alert.actions.map(\.title), ["Refresh", "Technical details", "Close"])
        XCTAssertTrue(alert.message?.contains("without sending them again") == true)
    }

    func testHistoryPaginationFailureKeepsRowsAndRetriesTheSameCursor() async throws {
        reader.paged = true
        let controller = try open()
        await waitUntil { controller.tableView.numberOfRows(inSection: 2) == 2 }
        XCTAssertEqual(content(controller, section: 2, row: 1)?.text, "Load more activity")
        reader.historyFailures = 1
        controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: 1, section: 2))
        await waitUntil { self.content(controller, section: 2, row: 1)?.secondaryText?.contains("Could not load more") == true }
        XCTAssertTrue(content(controller, section: 2)?.text?.hasPrefix("Sent 1.25") == true)
        controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: 1, section: 2))
        await waitUntil { self.content(controller, section: 2, row: 1)?.text?.hasPrefix("Received 2.5") == true }
        XCTAssertEqual(reader.historyCursors.compactMap { $0 }, ["next-page", "next-page"])
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 2), 2)
    }

    func testDuplicateHistoryPageDoesNotAppendOrAdvanceCursor() async throws {
        reader.paged = true
        reader.repeatsSourceID = true
        let controller = try open()
        await waitUntil { controller.tableView.numberOfRows(inSection: 2) == 2 }
        controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: 1, section: 2))
        await waitUntil { self.content(controller, section: 2, row: 1)?.secondaryText != nil }
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 2), 2)
        XCTAssertEqual(content(controller, section: 2, row: 1)?.text, "Load more activity")
        reader.repeatsSourceID = false
        controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: 1, section: 2))
        await waitUntil { self.content(controller, section: 2, row: 1)?.text?.hasPrefix("Received") == true }
        XCTAssertEqual(reader.historyCursors.compactMap { $0 }, ["next-page", "next-page"])
    }

    func testChangingSelectedWalletRevokesRetainedCopyAction() throws {
        let controller = try open(.minamoto)
        let copy = try XCTUnwrap(views(UIButton.self, in: controller.view).first { $0.currentTitle == "Copy address" })
        let clipboard = UIPasteboard.general.items
        defer { UIPasteboard.general.items = clipboard }
        UIPasteboard.general.string = "unchanged fixture clipboard"
        SelectedWalletSettings.shared.commitInternalValue(nil)
        copy.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, "unchanged fixture clipboard")
        XCTAssertFalse(navigation.viewControllers.contains { $0 === controller })
    }
}

@MainActor
private final class NexusScreenReader: NexusToriiReading {
    var account = ""
    var balanceFailure = false
    var historyFailures = 0
    var paged = false
    var repeatsSourceID = false
    private(set) var balanceReads = 0
    private(set) var historyCursors: [String?] = []
    func xorAssetDefinition(configuration: NexusNetworkConfiguration) async throws -> NexusAssetDefinition {
        if balanceFailure { throw NexusToriiError.invalidResponse }
        return NexusAssetDefinition(id: NexusAssetDefinitionIdentity.tairaXorDefinitionID)
    }
    func accountAssets(account: String, configuration: NexusNetworkConfiguration, asset: String, limit: Int, offset: Int) async throws -> NexusAccountAssetList {
        balanceReads += 1
        let data = try JSONSerialization.data(withJSONObject: ["items": [["account_id": account, "asset": asset,
            "asset_name": "xor", "asset_alias": "xor#universal", "quantity": "12.500000001", "scope": "global"]],
            "has_more": false, "count_mode": "exact", "total": 1])
        return try JSONDecoder().decode(NexusAccountAssetList.self, from: data)
    }
    func transferHistoryPage(account: String, configuration: NexusNetworkConfiguration, assetDefinitionID: String, cursor: String?) async throws -> NexusCursorHistoryPage {
        historyCursors.append(cursor)
        if historyFailures > 0 { historyFailures -= 1; throw NexusToriiError.invalidResponse }
        let first = NexusTransferHistoryItem(transactionHash: "first-transaction", timestampMilliseconds: 1_700_000_000_000,
            amount: try PIQuantity("1.25"), sender: account, receiver: "recipient")
        let second = NexusTransferHistoryItem(transactionHash: "second-transaction", timestampMilliseconds: 1_700_000_100_000,
            amount: try PIQuantity("2.5"), sender: "sender", receiver: account)
        if !paged { return NexusCursorHistoryPage(items: [first, second], sourceItemIDs: ["first", "second"], nextCursor: nil) }
        if cursor == nil { return NexusCursorHistoryPage(items: [first], sourceItemIDs: ["first"], nextCursor: "next-page") }
        return NexusCursorHistoryPage(items: [second], sourceItemIDs: [repeatsSourceID ? "first" : "second"], nextCursor: nil)
    }
    func status(hash: String, configuration: NexusNetworkConfiguration) async throws -> NexusPipelineStatus { throw NexusToriiError.invalidResponse }
    func hasAuthoritativeCommittedTransaction(account: String, configuration: NexusNetworkConfiguration, assetDefinitionID: String, transactionHash: String) async throws -> Bool { false }
    func committedXorTransfers(account: String, configuration: NexusNetworkConfiguration, assetDefinitionID: String, transactionHash: String) async throws -> [NexusTransferHistoryItem] { [] }
}
