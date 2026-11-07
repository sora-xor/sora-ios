// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import NexusTransferCodec
import SoraFoundation
import SoraKeystore
import SoraUIKit
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
    private var directories = [URL]()

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
        directories.forEach { try? FileManager.default.removeItem(at: $0) }; directories = []
        super.tearDown()
    }
    private func account(_ configuration: NexusNetworkConfiguration) throws -> NetworkAccount {
        NetworkAccount(walletId: selected.address, networkId: configuration.networkId, derivationVersion: 1,
            publicKey: Data(repeating: 3, count: 32),
            address: try IrohaAddressCodec.encode(publicKeyHex: String(repeating: "03", count: 32),
                                                 chainDiscriminant: configuration.i105Discriminant))
    }
    private func open(_ configuration: NexusNetworkConfiguration? = nil, coordinator: NexusTransactionCoordinator? = nil) throws -> NexusNetworkDetailViewController {
        let configuration = try configuration ?? XCTUnwrap(NexusNetworkConfiguration.taira)
        let account = try account(configuration)
        reader.account = account.address
        let controller = NexusNetworkDetailViewController(account: account, configuration: configuration,
            coordinator: coordinator, readClient: reader, mutationUnavailableReason: "Fixture journal unavailable", faucetService: ScreenNoFaucet())
        navigation.pushViewController(controller, animated: false)
        controller.loadViewIfNeeded()
        window.layoutIfNeeded()
        return controller
    }
    private func balance(_ controller: NexusNetworkDetailViewController) -> String? {
        controller.balanceItem?.balanceText
    }
    private func rows(_ controller: NexusNetworkDetailViewController) -> [ActivityContentViewModel] {
        controller.activityItem?.rows ?? []
    }
    private func amount(_ row: ActivityContentViewModel) -> String {
        row.firstBalanceText.attributedString.string
    }
    private func historyRows(_ controller: NexusNetworkDetailViewController) -> [ActivityContentViewModel] {
        rows(controller).filter { !$0.txHash.hasPrefix(NexusActivityRows.pendingPrefix) }
    }
    private func pendingRows(_ controller: NexusNetworkDetailViewController) -> [ActivityContentViewModel] {
        rows(controller).filter { $0.txHash.hasPrefix(NexusActivityRows.pendingPrefix) }
    }
    /// The transaction details SORA2's details screen shows for a row.
    private func presentedDetails(_ controller: UIViewController) -> NexusActivityDetailsViewModel? {
        (controller.presentedViewController?.children.first as? ActivityDetailsViewController)?.viewModel
            as? NexusActivityDetailsViewModel
    }
    private func presentedReceive(_ controller: UIViewController) -> NexusReceiveViewModel? {
        ((controller.presentedViewController?.children.first as? UINavigationController)?
            .viewControllers.first as? ReceiveViewController)?.viewModel as? NexusReceiveViewModel
    }
    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Fixture screen did not settle", file: file, line: line)
    }

    func testProductionAddressScreenIsExplicitlyOfflineAndCopiesOnlyItsAddress() throws {
        let controller = try open(.minamoto)
        XCTAssertEqual(balance(controller), "Coming soon")
        XCTAssertEqual(controller.balanceItem?.showsSend, false)
        XCTAssertEqual(reader.balanceReads, 0)
        XCTAssertTrue(reader.historyCursors.isEmpty)
        XCTAssertTrue(controller.balanceItem?.notes.contains { $0.contains("production address is ready") } == true)
        XCTAssertNil(controller.activityItem, "An offline network has no activity card")
        XCTAssertNil(controller.balanceItem?.faucet)
        XCTAssertEqual(controller.addressItem?.assetId, reader.account)
        let clipboard = UIPasteboard.general.items
        defer { UIPasteboard.general.items = clipboard }
        controller.addressItem?.tapHandler?()
        XCTAssertEqual(UIPasteboard.general.string, reader.account)
        // Receive is SORA2's Receive screen with the production address.
        controller.balanceItem?.actionHandler?(.receive)
        let receive = try XCTUnwrap(presentedReceive(controller))
        XCTAssertEqual(receive.address, reader.account)
        XCTAssertTrue(receive.notice?.contains("production address is ready") == true)
    }

    func testTairaReadOnlyScreenShowsExactBalanceHistoryAndJournalRecovery() async throws {
        let controller = try open()
        await waitUntil { self.balance(controller) == "12.500000001 XOR" }
        await waitUntil { self.historyRows(controller).count == 2 }
        XCTAssertEqual(controller.balanceItem?.showsSend, false, "No journal means no Send")
        XCTAssertTrue(controller.activityItem?.notice?.hasPrefix("Recovery required") == true)
        let rows = historyRows(controller)
        XCTAssertEqual(rows[0].title, "Sent")
        XCTAssertEqual(amount(rows[0]), "1.25 XOR")
        XCTAssertEqual(rows[0].subtitle, "recipient")
        XCTAssertEqual(rows[1].title, "Received")
        XCTAssertEqual(amount(rows[1]), "+ 2.5 XOR")
        XCTAssertEqual(rows[1].subtitle, "sender")
        XCTAssertEqual(reader.historyCursors.count, 1)
        XCTAssertNil(try XCTUnwrap(reader.historyCursors.first))
        XCTAssertTrue(controller.priceItem?.priceText?.hasPrefix("Taira") == true)
        XCTAssertEqual(controller.addressItem?.assetId, reader.account)
        controller.activityItem?.openDetails?("first-transaction")
        let details = try XCTUnwrap(presentedDetails(controller))
        XCTAssertEqual(details.model.transactionId, "first-transaction")
        XCTAssertEqual(details.model.recipient, "recipient")
        XCTAssertEqual(details.model.sender, reader.account)
        XCTAssertEqual(details.model.status, .success)
        XCTAssertEqual(details.model.amount, "1.25")
    }

    func testUnavailableBalanceCannotBeShownAsZeroOrUsedToRequestHistory() async throws {
        reader.balanceFailure = true
        let controller = try open()
        await waitUntil { self.balance(controller) == WalletUX.balanceUnavailableText }
        XCTAssertTrue(controller.activityItem?.notice?.contains("History unavailable") == true)
        XCTAssertTrue(reader.historyCursors.isEmpty)
        XCTAssertEqual(controller.balanceItem?.showsSend, false)
        XCTAssertFalse(balance(controller)?.contains("0") ?? true)
    }

    func testUnavailableHistoryKeepsBalanceAndOffersReadOnlyRefresh() async throws {
        reader.historyFailures = 1
        let controller = try open()
        await waitUntil { controller.activityItem?.notice?.contains("History unavailable") == true }
        XCTAssertEqual(balance(controller), "12.500000001 XOR")
        controller.activityItem?.openNotice?()
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "Check connection")
        XCTAssertEqual(alert.actions.map(\.title), ["Refresh", "Technical details", "Close"])
        XCTAssertTrue(alert.message?.contains("without sending them again") == true)
    }

    func testHistoryPaginationFailureKeepsRowsAndRetriesTheSameCursor() async throws {
        reader.paged = true
        let controller = try open()
        await waitUntil { self.historyRows(controller).count == 1 && controller.activityItem?.moreTitle != nil }
        XCTAssertEqual(controller.activityItem?.moreTitle, "Show more")
        reader.historyFailures = 1
        controller.activityItem?.openMore?()
        await waitUntil { controller.activityItem?.notice?.contains("Could not load more") == true }
        XCTAssertEqual(historyRows(controller).first?.title, "Sent")
        XCTAssertEqual(historyRows(controller).first.map(amount), "1.25 XOR")
        controller.activityItem?.openMore?()
        await waitUntil { self.historyRows(controller).count == 2 }
        XCTAssertEqual(historyRows(controller)[1].title, "Received")
        XCTAssertEqual(reader.historyCursors.compactMap { $0 }, ["next-page", "next-page"])
        XCTAssertNil(controller.activityItem?.moreTitle, "Every transfer is listed")
    }

    func testDuplicateHistoryPageDoesNotAppendOrAdvanceCursor() async throws {
        reader.paged = true
        reader.repeatsSourceID = true
        let controller = try open()
        await waitUntil { self.historyRows(controller).count == 1 && controller.activityItem?.moreTitle != nil }
        controller.activityItem?.openMore?()
        await waitUntil { controller.activityItem?.notice?.contains("Could not load more") == true }
        XCTAssertEqual(historyRows(controller).count, 1)
        XCTAssertEqual(controller.activityItem?.moreTitle, "Show more")
        reader.repeatsSourceID = false
        controller.activityItem?.openMore?()
        await waitUntil { self.historyRows(controller).last?.title == "Received" }
        XCTAssertEqual(reader.historyCursors.compactMap { $0 }, ["next-page", "next-page"])
    }

    func testChangingSelectedWalletRevokesRetainedCopyAction() throws {
        let controller = try open(.minamoto)
        let copy = try XCTUnwrap(controller.addressItem?.tapHandler)
        let clipboard = UIPasteboard.general.items
        defer { UIPasteboard.general.items = clipboard }
        UIPasteboard.general.string = "unchanged fixture clipboard"
        SelectedWalletSettings.shared.commitInternalValue(nil)
        copy()
        XCTAssertEqual(UIPasteboard.general.string, "unchanged fixture clipboard")
        XCTAssertFalse(navigation.viewControllers.contains { $0 === controller })
    }

    func testDetailOpenedFromTheHomeIsSora2sModalAndClosesWhenTheWalletChanges() async throws {
        let configuration = try XCTUnwrap(NexusNetworkConfiguration.taira)
        let account = try account(configuration)
        reader.account = account.address
        let controller = NexusNetworkDetailViewController(account: account, configuration: configuration,
            coordinator: nil, readClient: reader, mutationUnavailableReason: nil, faucetService: ScreenNoFaucet())
        let root = try XCTUnwrap(navigation.viewControllers.first)
        NexusSora2Presentation.present(controller, from: root)
        controller.loadViewIfNeeded()
        let container = try XCTUnwrap(root.presentedViewController as? BlurViewController)
        XCTAssertTrue(controller.navigationController?.parent === container)
        XCTAssertNotNil(controller.navigationItem.rightBarButtonItem, "SORA2's close button")
        SelectedWalletSettings.shared.commitInternalValue(nil)
        controller.viewWillAppear(false)
        await waitUntil { root.presentedViewController == nil }
        XCTAssertNil(root.presentedViewController, "A stale network detail must not stay on screen")
    }
}

@MainActor
private final class NexusScreenReader: NexusToriiReading {
    var account = ""
    var balanceFailure = false
    var balanceCancellation = false
    var historyDelay: UInt64 = 0
    var historyFailures = 0
    var paged = false
    var repeatsSourceID = false
    private(set) var balanceReads = 0
    private(set) var historyCursors: [String?] = []
    func xorAssetDefinition(configuration: NexusNetworkConfiguration) async throws -> NexusAssetDefinition {
        if balanceCancellation { throw CancellationError() }
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
        if historyDelay > 0 { try await Task.sleep(nanoseconds: historyDelay) }
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

extension NexusScreenBehaviorTests {
    private func pendingFixture(
        states: [NexusPendingState] = [.rejected], asset: String = NexusAssetDefinitionIdentity.tairaXorDefinitionID,
        foreignWallet: Bool = false, includesHash: Bool = true
    ) async throws -> (NexusTransactionCoordinator, NexusPendingTransactionStore, URL) {
        let configuration = try XCTUnwrap(NexusNetworkConfiguration.taira)
        let boundAccount = try account(configuration)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        directories.append(directory)
        let pending = try NexusPendingTransactionStore(baseURL: directory)
        for (index, state) in states.enumerated() {
            let row = NexusPendingTransaction(
                id: UUID(), idempotencyKey: UUID(), walletId: foreignWallet ? "other-wallet" : selected.address,
                networkId: .taira, chainId: configuration.chainId,
                tairaDeployment: NexusPendingTairaDeploymentIdentity.admitted(for: configuration),
                signingNetworkId: TairaClient.networkLiteral,
                sender: boundAccount.address,
                receiver: try IrohaAddressCodec.encode(publicKeyHex: String(repeating: "04", count: 32), chainDiscriminant: configuration.i105Discriminant),
                assetDefinitionID: asset, amount: try PIQuantity("\(index + 1).25"), fee: try PIQuantity("0.01"),
                createdAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: TimeInterval(200 + index)),
                hash: includesHash ? String(format: "%064x", index + 1) : nil,
                state: state, terminalBlockHeight: nil, errorClass: nil, historyReconciledAt: nil)
            try await pending.put(row)
        }
        let model = NexusTransactionCoordinator(readClient: reader, submissionClient: ScreenNoSubmission(),
            signer: UnavailableNexusTransactionSigner(), finalityReader: UnavailableNexusFinalityReader(), pendingStore: pending)
        return (model, pending, directory)
    }
    func testCurrentAssetPendingRowShowsExactAmountAndRetainedStatus() async throws {
        let (coordinator, _, _) = try await pendingFixture()
        let controller = try open(coordinator: coordinator)
        await waitUntil { self.pendingRows(controller).first.map(self.amount) == "1.25 XOR" }
        let row = try XCTUnwrap(pendingRows(controller).first)
        XCTAssertEqual(row.title, "Sent")
        XCTAssertEqual(row.subtitle, WalletUX.status(.rejected))
        XCTAssertEqual(row.status, .failed)
        XCTAssertEqual(rows(controller).first?.txHash, row.txHash, "Pending sends are listed first")
    }
    func testSelectingPendingRowShowsItsExactTransactionIdentifier() async throws {
        let (coordinator, _, _) = try await pendingFixture()
        let controller = try open(coordinator: coordinator)
        await waitUntil { self.balance(controller) == "12.500000001 XOR" && !self.pendingRows(controller).isEmpty }
        let id = try XCTUnwrap(pendingRows(controller).first?.txHash)
        controller.activityItem?.openDetails?(id)
        let details = try XCTUnwrap(presentedDetails(controller))
        XCTAssertEqual(details.model.statusText, WalletUX.status(.rejected))
        XCTAssertEqual(details.model.transactionId, String(format: "%064x", 1))
        XCTAssertEqual(details.model.note, WalletUX.statusDetail(.rejected))
        XCTAssertEqual(details.model.amount, "1.25")
        XCTAssertEqual(details.model.fee, "0.01")
    }
    func testFailedPreSubmissionRowDoesNotInventATransactionIdentifier() async throws {
        let (coordinator, _, _) = try await pendingFixture(states: [.failedBeforeSubmission], includesHash: false)
        let controller = try open(coordinator: coordinator)
        await waitUntil { self.balance(controller) == "12.500000001 XOR" && !self.pendingRows(controller).isEmpty }
        let id = try XCTUnwrap(pendingRows(controller).first?.txHash)
        controller.activityItem?.openDetails?(id)
        let details = try XCTUnwrap(presentedDetails(controller))
        XCTAssertNil(details.model.transactionId)
        XCTAssertEqual(details.model.note, WalletUX.statusDetail(.failedBeforeSubmission))
    }
    func testPendingRowsArePresentedNewestFirst() async throws {
        let (coordinator, _, _) = try await pendingFixture(states: [.rejected, .expired])
        let controller = try open(coordinator: coordinator)
        await waitUntil { self.pendingRows(controller).count == 2 }
        XCTAssertEqual(pendingRows(controller).map(amount), ["2.25 XOR", "1.25 XOR"])
    }
    func testPendingTransfersForAnotherWalletAreNotShownOnThisAccount() async throws {
        let (coordinator, _, _) = try await pendingFixture(foreignWallet: true)
        let controller = try open(coordinator: coordinator)
        await waitUntil { self.balance(controller) == "12.500000001 XOR" && self.historyRows(controller).count == 2 }
        XCTAssertTrue(pendingRows(controller).isEmpty)
    }
    func testUnreadablePendingJournalKeepsReadOnlyBalanceAndExplainsRecovery() async throws {
        let (coordinator, _, directory) = try await pendingFixture()
        try Data("broken journal".utf8).write(to: directory.appendingPathComponent("SORA/PendingTransactions/nexus-v1.json"))
        let controller = try open(coordinator: coordinator)
        await waitUntil { self.balance(controller) == "12.500000001 XOR" }
        await waitUntil { controller.activityItem?.notice?.hasPrefix("Recovery required") == true }
        XCTAssertEqual(controller.balanceItem?.showsSend, false)
        XCTAssertTrue(pendingRows(controller).isEmpty)
    }
    func testPullToRefreshReplacesAnUnavailableBalanceWithAFreshVerifiedRead() async throws {
        reader.balanceFailure = true
        let controller = try open()
        await waitUntil { self.balance(controller) == WalletUX.balanceUnavailableText }
        reader.balanceFailure = false; controller.refreshControl.sendActions(for: .valueChanged)
        await waitUntil { self.balance(controller) == "12.500000001 XOR" }
        await waitUntil { self.historyRows(controller).count == 2 }
        XCTAssertFalse(controller.refreshControl.isRefreshing)
    }
    func testForegroundNotificationRefreshesTheVisibleNetworkScreen() async throws {
        let controller = try open()
        await waitUntil { self.balance(controller) == "12.500000001 XOR" }
        let previousReads = reader.balanceReads
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        await waitUntil { self.reader.balanceReads > previousReads }
        XCTAssertEqual(balance(controller), "12.500000001 XOR")
    }
    func testForegroundNotificationDoesNotReloadAnOffscreenRetainedController() async throws {
        let controller = try open()
        await waitUntil { self.balance(controller) == "12.500000001 XOR" }
        navigation.popViewController(animated: false)
        await waitUntil { controller.view.window == nil }
        let previousReads = reader.balanceReads
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(reader.balanceReads, previousReads)
    }
    func testDisablingTairaRevokesTheDetailAtItsNextAppearance() throws {
        let controller = try open()
        SettingsManager.shared.isTairaEnabled = false
        controller.viewWillAppear(false)
        XCTAssertFalse(navigation.viewControllers.contains { $0 === controller })
        XCTAssertFalse(controller.balanceItem?.showsSend ?? false)
    }
    func testWalletChangeDuringHistoryReadCannotPublishTheOldAccountHistory() async throws {
        reader.historyDelay = 80_000_000
        let controller = try open()
        await waitUntil { !self.reader.historyCursors.isEmpty }
        SelectedWalletSettings.shared.commitInternalValue(nil)
        await waitUntil { !self.navigation.viewControllers.contains { $0 === controller } }
        try? await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertTrue(historyRows(controller).isEmpty)
    }
    func testCancellationDoesNotMislabelTheBalanceAsUnavailable() async throws {
        reader.balanceCancellation = true
        let controller = try open()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNotEqual(balance(controller), WalletUX.balanceUnavailableText)
        XCTAssertTrue(reader.historyCursors.isEmpty)
        XCTAssertFalse(controller.refreshControl.isRefreshing)
    }
}

private struct ScreenNoSubmission: NexusToriiSubmitting {
    func submit(signedNorito: Data, idempotencyKey: UUID, expectedHash: String,
                configuration: NexusNetworkConfiguration) async throws -> NexusToriiSubmissionResult {
        XCTFail("A read-only screen must never submit a transaction")
        throw NexusToriiError.invalidResponse
    }
}

private struct ScreenNoFaucet: TairaFaucetServing {
    func hasPending(account: String) async throws -> Bool { false }
    func request(account: NetworkAccount, configuration: NexusNetworkConfiguration,
                 contextIsCurrent: @escaping @Sendable () async -> Bool,
                 progress: @escaping @Sendable (TairaFaucetService.Phase) async -> Void) async throws -> TairaFaucetClient.Outcome {
        XCTFail("Refreshing a screen cannot request faucet funds")
        throw NexusToriiError.invalidResponse
    }
}
