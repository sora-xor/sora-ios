// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import NexusTransferCodec
import SoraFoundation
import SoraKeystore
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class TairaFaucetScreenTests: XCTestCase {
  private var previousWindow: UIWindow?
  private var previousLanguage = "en"
  private var window: UIWindow!
  private var navigation: UINavigationController!
  private var previousAccount: AccountItem?
  private var oldNexus = false
  private var oldTaira = false
  private var oldAnimations = true
  private var reader: FaucetScreenReader!
  private var selected: AccountItem!
  private var faucet: FaucetScreenService!

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
    selected = AccountItem(
      address: "network-screen-fixture", cryptoType: .sr25519, networkType: 69,
      username: "Network screen fixture", publicKeyData: Data(repeating: 1, count: 32),
      settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0,
      isSelected: true)
    SelectedWalletSettings.shared.commitInternalValue(selected)
    reader = FaucetScreenReader()
    faucet = FaucetScreenService()
    navigation = UINavigationController(rootViewController: UIViewController())
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    previousWindow = scene?.windows.first { $0.isKeyWindow }
    window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
    window.frame = scene?.coordinateSpace.bounds ?? UIScreen.main.bounds
    window.rootViewController = navigation
    window.makeKeyAndVisible()
  }
  override func tearDown() {
    faucet.releaseAll()
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
    NetworkAccount(
      walletId: selected.address, networkId: configuration.networkId, derivationVersion: 1,
      publicKey: Data(repeating: 3, count: 32),
      address: try IrohaAddressCodec.encode(
        publicKeyHex: String(repeating: "03", count: 32),
        chainDiscriminant: configuration.i105Discriminant))
  }
  private func openRaw(_ configuration: NexusNetworkConfiguration? = nil) throws
    -> NexusNetworkDetailViewController
  {
    let configuration = try configuration ?? XCTUnwrap(NexusNetworkConfiguration.taira)
    let account = try account(configuration)
    reader.account = account.address
    let controller = NexusNetworkDetailViewController(
      account: account, configuration: configuration,
      coordinator: nil, readClient: reader,
      mutationUnavailableReason: "Fixture journal unavailable", faucetService: faucet)
    navigation.pushViewController(controller, animated: false)
    controller.loadViewIfNeeded()
    window.layoutIfNeeded()
    return controller
  }
  private func content(_ controller: NexusNetworkDetailViewController, section: Int, row: Int = 0)
    -> UIListContentConfiguration?
  {
    controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: row, section: section))
      .contentConfiguration as? UIListContentConfiguration
  }
  private func waitUntil(
    _ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line
  ) async {
    for _ in 0..<200 {
      if condition() { return }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Fixture screen did not settle", file: file, line: line)
  }
  private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
    ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) }
  }

  private func open() async throws -> NexusNetworkDetailViewController {
    let screen = try openRaw()
    await waitUntil { self.faucet.pendingReads > 0 }
    // hasPending returns synchronously in this fixture; allow the UI task's defer to complete.
    await Task.yield()
    return screen
  }
  private func button(_ screen: UIViewController) throws -> UIButton {
    try XCTUnwrap(
      views(UIButton.self, in: screen.view).first {
        $0.accessibilityIdentifier == "taira.faucet.request"
      })
  }
  private func status(_ screen: UIViewController) throws -> UILabel {
    try XCTUnwrap(
      views(UILabel.self, in: screen.view).first {
        $0.accessibilityIdentifier == "taira.faucet.status"
      })
  }
  private func tap(_ screen: UIViewController) throws {
    try button(screen).sendActions(for: .touchUpInside)
  }
  private func settled(_ screen: UIViewController) async throws {
    let button = try button(screen)
    await waitUntil {
      self.faucet.requests > 0 && button.configuration?.showsActivityIndicator == false
    }
  }

  func testInitialScreenUsesPublicReceiveAccountForPendingLookup() async throws {
    let screen = try await open()
    XCTAssertEqual(faucet.pendingAccounts, [reader.account])
    XCTAssertEqual(try status(screen).text, "Free XOR for testing on Taira.")
    XCTAssertEqual(try button(screen).configuration?.title, "Get test XOR")
  }
  func testSavedPendingRequestOffersStatusCheck() async throws {
    faucet.pending = true
    let screen = try await open()
    XCTAssertEqual(try button(screen).configuration?.title, "Check faucet request")
    XCTAssertTrue(try status(screen).text?.contains("still processing") == true)
  }
  func testUnreadableSavedRequestDisablesNewClaim() async throws {
    faucet.pendingFailure = true
    let screen = try await open()
    await waitUntil { (try? self.button(screen).isEnabled) == false }
    XCTAssertTrue(try status(screen).text?.contains("could not be read") == true)
    XCTAssertEqual(faucet.requests, 0)
  }
  func testAppliedClaimShowsExactAmountAndReloadsBalance() async throws {
    let screen = try await open()
    await waitUntil { self.reader.balanceReads == 1 }
    try tap(screen)
    try await settled(screen)
    XCTAssertEqual(try status(screen).text, "Received 25000 test XOR.")
    await waitUntil { self.reader.balanceReads == 2 }
    XCTAssertEqual(faucet.requestedAccounts.map(\.address), [reader.account])
    XCTAssertEqual(faucet.requestedNetworks, [.taira])
  }
  func testRejectedClaimOffersNewAttemptWithoutReloadingBalance() async throws {
    faucet.resultKind = "Rejected"
    let screen = try await open()
    await waitUntil { self.reader.balanceReads == 1 }
    try tap(screen)
    try await settled(screen)
    XCTAssertTrue(try status(screen).text?.contains("not completed") == true)
    XCTAssertEqual(try button(screen).configuration?.title, "Get test XOR")
    XCTAssertEqual(reader.balanceReads, 1)
  }
  func testPendingClaimOffersReadOnlyStatusCheck() async throws {
    faucet.resultKind = "Queued"
    let screen = try await open()
    try tap(screen)
    try await settled(screen)
    XCTAssertEqual(try button(screen).configuration?.title, "Check faucet request")
    XCTAssertTrue(try status(screen).text?.contains("still processing") == true)
  }
  func testSuccessfulCheckClearsPreviouslyPendingButtonTitle() async throws {
    faucet.pending = true
    let screen = try await open()
    try tap(screen)
    try await settled(screen)
    XCTAssertEqual(try button(screen).configuration?.title, "Get test XOR")
    XCTAssertEqual(try status(screen).text, "Received 25000 test XOR.")
  }
  func testPreparingProgressIsVisibleWhileClaimIsBusy() async throws {
    try await assertProgress(.preparing, "Preparing your test XOR…")
  }
  func testSubmittingProgressIsVisibleWhileClaimIsBusy() async throws {
    try await assertProgress(.submitting, "Requesting test XOR…")
  }
  func testCheckingProgressIsVisibleWhileClaimIsBusy() async throws {
    try await assertProgress(.checking, "Checking your faucet request…")
  }
  private func assertProgress(_ phase: TairaFaucetService.Phase, _ text: String) async throws {
    faucet.phase = phase
    faucet.holdRequest = true
    let screen = try await open()
    try tap(screen)
    await waitUntil { (try? self.status(screen).text) == text }
    XCTAssertFalse(try button(screen).isEnabled)
    XCTAssertTrue(try button(screen).configuration?.showsActivityIndicator == true)
    faucet.releaseAll()
    try await settled(screen)
  }
  func testRepeatedTapWhileRequestIsHeldStartsOnlyOneClaim() async throws {
    faucet.holdRequest = true
    let screen = try await open()
    try tap(screen)
    await waitUntil { self.faucet.requests == 1 }
    try tap(screen)
    await Task.yield()
    XCTAssertEqual(faucet.requests, 1)
    faucet.releaseAll()
    try await settled(screen)
  }
  func testOfflineFailureWithoutPendingRequestOffersRetry() async throws {
    faucet.failure = URLError(.notConnectedToInternet)
    let screen = try await open()
    try tap(screen)
    try await settled(screen)
    XCTAssertTrue(try status(screen).text?.contains("Check your connection") == true)
    XCTAssertEqual(try button(screen).configuration?.title, "Get test XOR")
  }
  func testOfflineFailureWithPendingRequestPreservesCheckAction() async throws {
    faucet.failure = URLError(.networkConnectionLost)
    faucet.pending = true
    let screen = try await open()
    try tap(screen)
    try await settled(screen)
    XCTAssertTrue(try status(screen).text?.contains("still processing") == true)
    XCTAssertEqual(try button(screen).configuration?.title, "Check faucet request")
  }
  func testUnreadablePendingAfterRequestFailureDoesNotOfferDuplicateClaim() async throws {
    faucet.failure = URLError(.networkConnectionLost)
    let screen = try await open()
    faucet.pendingFailure = true
    try tap(screen)
    try await settled(screen)
    XCTAssertEqual(try button(screen).configuration?.title, "Check faucet request")
  }
  func testRateLimitUsesServerCooldownAndDoesNotRepeatClaim() async throws {
    try await assertCooldown(120, minimum: 118, maximum: 120)
  }
  func testMissingRateLimitUsesOneMinuteCooldown() async throws {
    try await assertCooldown(nil, minimum: 58, maximum: 60)
  }
  func testExcessiveRateLimitIsCappedAtOneDay() async throws {
    try await assertCooldown(999999, minimum: 86398, maximum: 86400)
  }
  func testNegativeRateLimitIsBoundedAboveZero() async throws {
    try await assertCooldown(-10, minimum: 1, maximum: 1)
  }
  private func assertCooldown(_ seconds: TimeInterval?, minimum: Int, maximum: Int) async throws {
    faucet.failure = TairaFaucetClient.Failure.rateLimited(retryAfterSeconds: seconds)
    let screen = try await open()
    try tap(screen)
    try await settled(screen)
    XCTAssertTrue(try status(screen).text?.contains("limit has been reached") == true)
    try tap(screen)
    let text = try XCTUnwrap(status(screen).text)
    let value = try XCTUnwrap(text.split(separator: " ").compactMap { Int($0) }.first)
    XCTAssertTrue((minimum...maximum).contains(value), text)
    XCTAssertEqual(faucet.requests, 1)
    XCTAssertTrue(try button(screen).isEnabled)
  }
  func testWalletChangeBeforeTapPreventsAnyFaucetCall() async throws {
    let screen = try await open()
    SelectedWalletSettings.shared.commitInternalValue(nil)
    try tap(screen)
    XCTAssertEqual(faucet.requests, 0)
    XCTAssertFalse(try button(screen).isEnabled)
  }
  func testDisabledNetworkBeforeTapPreventsAnyFaucetCall() async throws {
    let screen = try await open()
    SettingsManager.shared.isTairaEnabled = false
    try tap(screen)
    XCTAssertEqual(faucet.requests, 0)
    XCTAssertFalse(try button(screen).isEnabled)
  }
  func testWalletChangeDuringClaimCannotReenableStaleButton() async throws {
    faucet.holdRequest = true
    let screen = try await open()
    try tap(screen)
    await waitUntil { self.faucet.requests == 1 }
    SelectedWalletSettings.shared.commitInternalValue(nil)
    faucet.releaseAll()
    await waitUntil { self.faucet.completedRequests == 1 }
    for _ in 0..<5 { await Task.yield() }
    XCTAssertFalse(try button(screen).isEnabled)
    XCTAssertNotEqual(try status(screen).text, "Received 25000 test XOR.")
  }
  func testWalletChangeDuringErrorPendingLookupIgnoresLateMessage() async throws {
    faucet.failure = URLError(.networkConnectionLost)
    let screen = try await open()
    faucet.holdPending = true
    try tap(screen)
    await waitUntil { self.faucet.pendingReads == 2 }
    let oldText = try status(screen).text
    SelectedWalletSettings.shared.commitInternalValue(nil)
    faucet.releaseAll()
    for _ in 0..<10 { await Task.yield() }
    XCTAssertEqual(try status(screen).text, oldText)
    XCTAssertFalse(try button(screen).isEnabled)
  }
}

@MainActor
private final class FaucetScreenService: TairaFaucetServing {
  var pending = false
  var pendingFailure = false
  var holdPending = false
  var holdRequest = false
  var resultKind = "Applied"
  var failure: Error?
  var phase: TairaFaucetService.Phase = .preparing
  private(set) var pendingReads = 0
  private(set) var pendingAccounts: [String] = []
  private(set) var requestedAccounts: [NetworkAccount] = []
  private(set) var requestedNetworks: [NetworkId] = []
  private(set) var requests = 0
  private(set) var completedRequests = 0
  private var requestWaiter: CheckedContinuation<Void, Never>?
  private var pendingWaiter: CheckedContinuation<Void, Never>?
  func releaseAll() {
    holdPending = false
    holdRequest = false
    requestWaiter?.resume()
    requestWaiter = nil
    pendingWaiter?.resume()
    pendingWaiter = nil
  }
  func hasPending(account: String) async throws -> Bool {
    pendingReads += 1
    pendingAccounts.append(account)
    if holdPending { await withCheckedContinuation { pendingWaiter = $0 } }
    if pendingFailure { throw TairaFaucetService.Failure.unreadableRequest }
    return pending
  }
  func request(
    account: NetworkAccount, configuration: NexusNetworkConfiguration,
    contextIsCurrent: @escaping @Sendable () async -> Bool,
    progress: @escaping @Sendable (TairaFaucetService.Phase) async -> Void
  ) async throws -> TairaFaucetClient.Outcome {
    requests += 1
    requestedAccounts.append(account)
    requestedNetworks.append(configuration.networkId)
    defer { completedRequests += 1 }
    guard await contextIsCurrent() else { throw TairaFaucetService.Failure.wrongAccount }
    await progress(phase)
    if holdRequest { await withCheckedContinuation { requestWaiter = $0 } }
    if let failure { throw failure }
    // Parse an independently specified wire response with the real codec; no signing or remote request.
    let hash = String(repeating: "ab", count: 32)
    let body = try JSONSerialization.data(withJSONObject: [
      "hash": hash, "scope": "global", "resolved_from": "state",
      "status": ["kind": resultKind, "block_height": 75],
    ])
    let client = TairaFaucetClient(
      scrypt: { _, _, _, _, _ in Data() }, transport: { _, _ in .init(data: body) })
    return try await client.resume(transactionHash: hash, timeout: 0)
  }
}

@MainActor
private final class FaucetScreenReader: NexusToriiReading {
  var account = ""
  var balanceFailure = false
  var historyFailures = 0
  var paged = false
  var repeatsSourceID = false
  private(set) var balanceReads = 0
  private(set) var historyCursors: [String?] = []
  func xorAssetDefinition(configuration: NexusNetworkConfiguration) async throws
    -> NexusAssetDefinition
  {
    if balanceFailure { throw NexusToriiError.invalidResponse }
    return NexusAssetDefinition(id: NexusAssetDefinitionIdentity.tairaXorDefinitionID)
  }
  func accountAssets(
    account: String, configuration: NexusNetworkConfiguration, asset: String, limit: Int,
    offset: Int
  ) async throws -> NexusAccountAssetList {
    balanceReads += 1
    let data = try JSONSerialization.data(withJSONObject: [
      "items": [
        [
          "account_id": account, "asset": asset,
          "asset_name": "xor", "asset_alias": "xor#universal", "quantity": "12.500000001",
          "scope": "global",
        ]
      ],
      "has_more": false, "count_mode": "exact", "total": 1,
    ])
    return try JSONDecoder().decode(NexusAccountAssetList.self, from: data)
  }
  func transferHistoryPage(
    account: String, configuration: NexusNetworkConfiguration, assetDefinitionID: String,
    cursor: String?
  ) async throws -> NexusCursorHistoryPage {
    historyCursors.append(cursor)
    if historyFailures > 0 {
      historyFailures -= 1
      throw NexusToriiError.invalidResponse
    }
    let first = NexusTransferHistoryItem(
      transactionHash: "first-transaction", timestampMilliseconds: 1_700_000_000_000,
      amount: try PIQuantity("1.25"), sender: account, receiver: "recipient")
    let second = NexusTransferHistoryItem(
      transactionHash: "second-transaction", timestampMilliseconds: 1_700_000_100_000,
      amount: try PIQuantity("2.5"), sender: "sender", receiver: account)
    if !paged {
      return NexusCursorHistoryPage(
        items: [first, second], sourceItemIDs: ["first", "second"], nextCursor: nil)
    }
    if cursor == nil {
      return NexusCursorHistoryPage(
        items: [first], sourceItemIDs: ["first"], nextCursor: "next-page")
    }
    return NexusCursorHistoryPage(
      items: [second], sourceItemIDs: [repeatsSourceID ? "first" : "second"], nextCursor: nil)
  }
  func status(hash: String, configuration: NexusNetworkConfiguration) async throws
    -> NexusPipelineStatus
  { throw NexusToriiError.invalidResponse }
  func hasAuthoritativeCommittedTransaction(
    account: String, configuration: NexusNetworkConfiguration, assetDefinitionID: String,
    transactionHash: String
  ) async throws -> Bool { false }
  func committedXorTransfers(
    account: String, configuration: NexusNetworkConfiguration, assetDefinitionID: String,
    transactionHash: String
  ) async throws -> [NexusTransferHistoryItem] { [] }
}
