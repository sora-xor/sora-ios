// SPDX-License-Identifier: Apache-2.0
import Foundation
import NexusTransferCodec
import SoraFoundation
import SoraKeystore
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class NexusNetworkFlowTests: XCTestCase {
  private var directories: [URL] = []
  private let sender = "testuﾛ1Q1ﾘﾚxgﾁﾃﾀdRZﾀWｿfXLGﾜﾘPﾐﾉﾉkﾃ7ﾖｶBｹssﾙﾈjｷｹUNYWHP"
  private let receiver = "testuﾛ1NｼXCeｱﾈﾁRｴUﾀPWﾏVｱrﾋhESEbpﾂｾ9Vﾗ5ﾇJｵavsｷ26TMSNN"
  private let asset = NexusAssetDefinitionIdentity.tairaXorDefinitionID
  private let transactionHash = String(repeating: "a", count: 64)
  private var previous: AccountItem?, oldWindow: UIWindow?, window: UIWindow!,
    navigation: UINavigationController!
  private var oldNexus = false, oldTaira = false, oldAnimations = true, language = "en"
  override func setUp() {
    super.setUp()
    previous = SelectedWalletSettings.shared.currentAccount
    oldNexus = SettingsManager.shared.nexusEnabled
    oldTaira = SettingsManager.shared.isTairaEnabled
    SettingsManager.shared.nexusEnabled = true
    SettingsManager.shared.isTairaEnabled = true
    language = LocalizationManager.shared.selectedLocalization
    LocalizationManager.shared.selectedLocalization = "en"
    oldAnimations = UIView.areAnimationsEnabled
    UIView.setAnimationsEnabled(false)
    SelectedWalletSettings.shared.commitInternalValue(
      AccountItem(
        address: "public-fixture", cryptoType: .sr25519, networkType: 69,
        username: "Public fixture", publicKeyData: Data(repeating: 7, count: 32),
        settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0,
        isSelected: true))
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    oldWindow = scene?.windows.first { $0.isKeyWindow }
    window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
    navigation = UINavigationController(rootViewController: UIViewController())
    window.rootViewController = navigation
    window.makeKeyAndVisible()
  }
  override func tearDown() {
    navigation.dismiss(animated: false)
    navigation.popToRootViewController(animated: false)
    window.isHidden = true
    window.rootViewController = nil
    window = nil
    navigation = nil
    SelectedWalletSettings.shared.commitInternalValue(previous)
    SettingsManager.shared.nexusEnabled = oldNexus
    SettingsManager.shared.isTairaEnabled = oldTaira
    UIView.setAnimationsEnabled(oldAnimations)
    LocalizationManager.shared.selectedLocalization = language
    oldWindow?.makeKeyAndVisible()
    for url in directories { try? FileManager.default.removeItem(at: url) }
    directories.removeAll()
    super.tearDown()
  }
  private struct Fixture {
    let model: NexusTransactionCoordinator
    let read: NetworkUIRead
    let sign: NetworkUISign
    let finality: NetworkUIFinality
    let transport: NetworkUITransport
    let pending: NexusPendingTransactionStore
    let settings: InMemorySettingsManager
    let store: WalletNetworkStore
    let gate: WalletRecoveryCapabilityGate
    let account: NetworkAccount
    let request: NexusTransferRequest
    var selection: NetworkUISelection
  }
  private func make(amount: String = "2") throws -> Fixture {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    directories.append(directory)
    let settings = InMemorySettingsManager()
    settings.nexusEnabled = true
    settings.isTairaEnabled = true
    let gate = WalletRecoveryCapabilityGate(
      settings: settings, unresolvedMigrationJournal: { false },
      unresolvedWalletCommitJournal: { false })
    let store = try WalletNetworkStore(baseURL: directory, recoveryGate: gate)
    let account = NetworkAccount(
      walletId: "public-fixture", networkId: .taira, derivationVersion: 1,
      publicKey: try Data(
        hex: "ebe2fe329305f8e4c19cc4b159bc6ddd413cf5831422bdb9b3b93ee5053bd4d3"),
      address: sender)
    let minamoto = NetworkAccount(
      walletId: account.walletId, networkId: .minamoto, derivationVersion: 1,
      publicKey: try Data(
        hex: "8dea60946dd00558e61254c7aadeccabd1e39d5b9a12a45b678e22209f19426f"),
      address: "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y")
    let legacy = NetworkAccount(
      walletId: account.walletId, networkId: .sora2, derivationVersion: 0,
      publicKey: Data(repeating: 7, count: 32), address: account.walletId)
    try store.stageAndActivate(
      WalletNetworkSnapshot(
        schemaVersion: 1, selectedWalletId: account.walletId,
        wallets: [
          WalletIdentity(
            id: account.walletId, displayName: "Public fixture",
            existingSoraAddress: account.walletId, secretSource: .mnemonicEntropy)
        ],
        accounts: [legacy, minamoto, account], createdAt: Date(timeIntervalSince1970: 1)))
    let read = NetworkUIRead(
      account: sender, receiver: receiver, asset: asset, hash: transactionHash)
    let sign = NetworkUISign(hash: transactionHash)
    let finality = NetworkUIFinality()
    let transport = NetworkUITransport(hash: transactionHash)
    let pending = try NexusPendingTransactionStore(baseURL: directory)
    let model = NexusTransactionCoordinator(
      readClient: read, submissionClient: transport, signer: sign, finalityReader: finality,
      pendingStore: pending, settings: settings, networkStore: { store },
      lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: gate), recoveryGate: gate)
    return Fixture(
      model: model, read: read, sign: sign, finality: finality, transport: transport,
      pending: pending,
      settings: settings, store: store, gate: gate, account: account,
      request: NexusTransferRequest(
        walletId: account.walletId, networkId: .taira, sender: sender, receiver: receiver,
        amount: try PIQuantity(amount)),
      selection: NetworkUISelection(account))
  }
  private func wait(_ condition: () -> Bool) async {
    for _ in 0..<200 {
      if condition() { return }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTFail("Network UI did not settle")
  }
  private func views<T: UIView>(_ type: T.Type, _ view: UIView) -> [T] {
    ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, $0) }
  }
  private func findButton(_ title: String, _ view: UIView) -> UIButton? {
    views(UIButton.self, view).first { ($0.configuration?.title ?? $0.currentTitle) == title }
  }
  private func button(_ title: String, _ view: UIView) throws -> UIButton {
    try XCTUnwrap(findButton(title, view))
  }
  private func texts(_ view: UIView) -> [String] { views(UILabel.self, view).compactMap(\.text) }
  private func open(_ f: Fixture, auto: Bool = false) throws -> NexusNetworkDetailViewController {
    let screen = NexusNetworkDetailViewController(
      account: f.account, configuration: NexusNetworkConfiguration.taira!, coordinator: f.model,
      readClient: f.read, mutationUnavailableReason: nil, opensSendWhenReady: auto,
      networkStore: { f.store })
    navigation.pushViewController(screen, animated: false)
    screen.loadViewIfNeeded()
    return screen
  }
  private func form(_ screen: NexusNetworkDetailViewController) throws -> NexusSendViewController {
    try XCTUnwrap(
      (screen.presentedViewController as? UINavigationController)?.topViewController
        as? NexusSendViewController)
  }
  private func openForm(_ f: Fixture) async throws -> (
    NexusNetworkDetailViewController, NexusSendViewController
  ) {
    let screen = try open(f, auto: true)
    await wait { screen.presentedViewController != nil }
    return (screen, try form(screen))
  }
  private func fill(_ form: NexusSendViewController, receiver: String? = nil, amount: String = "2")
    throws
  {
    try XCTUnwrap(
      views(UITextView.self, form.view).first { $0.accessibilityLabel == "Recipient address" }
    ).text = receiver ?? self.receiver
    try XCTUnwrap(views(UITextField.self, form.view).first).text = amount
    try button("Review send", form.view).sendActions(for: .touchUpInside)
  }
  private func portfolio(
    _ f: Fixture, balances: NetworkUIBalances? = nil,
    onSora: @escaping @MainActor () -> Bool = { false }
  ) async -> NexusPortfolioViewController {
    let screen = NexusPortfolioViewController(
      assetsProvider: balances, readClient: f.read, openSora2Experience: onSora,
      networkStore: { f.store })
    navigation.pushViewController(screen, animated: false)
    screen.loadViewIfNeeded()
    await wait { screen.tableView.numberOfRows(inSection: 0) > 0 }
    return screen
  }
  private func content(_ screen: NexusPortfolioViewController, _ row: Int)
    -> UIListContentConfiguration?
  {
    screen.tableView(screen.tableView, cellForRowAt: IndexPath(row: row, section: 0))
      .contentConfiguration as? UIListContentConfiguration
  }
  private func index(_ prefix: String, _ screen: NexusPortfolioViewController) throws -> Int {
    try XCTUnwrap(
      (0..<screen.tableView.numberOfRows(inSection: 0)).first {
        content(screen, $0)?.text?.contains(prefix) == true
      })
  }
  func testPortfolioShowsThreeNetworksWithExactBalances() async throws {
    let f = try make()
    let b = NetworkUIBalances()
    let screen = await portfolio(f, balances: b)
    let taira = try index("Taira", screen)
    await wait { self.content(screen, taira)?.secondaryText?.contains("100 XOR") == true }
    XCTAssertEqual(screen.tableView.numberOfRows(inSection: 0), 3)
    XCTAssertTrue(
      try content(screen, index("SORA2", screen))?.secondaryText?.contains("7 XOR") == true)
    XCTAssertTrue(
      try content(screen, index("SORA Nexus", screen))?.secondaryText?.contains("Address ready")
        == true)
  }
  func testExplicitTestnetOffHidesItsRowWithoutRemoteReads() async throws {
    let f = try make()
    SettingsManager.shared.isTairaEnabled = false
    let screen = await portfolio(f)
    XCTAssertEqual(screen.tableView.numberOfRows(inSection: 0), 2)
    XCTAssertEqual(f.read.definitionReads, 0)
  }
  func testDisabledNexusShowsOnlyLegacyNetwork() async throws {
    let f = try make()
    SettingsManager.shared.nexusEnabled = false
    let screen = await portfolio(f)
    XCTAssertEqual(screen.tableView.numberOfRows(inSection: 0), 1)
    XCTAssertTrue(
      screen.tableView(screen.tableView, titleForFooterInSection: 0)?.contains("Only SORA2") == true
    )
  }
  func testSoraRowUsesExistingWalletRoute() async throws {
    let f = try make()
    var calls = 0
    let screen = await portfolio(
      f,
      onSora: {
        calls += 1
        return true
      })
    screen.tableView(
      screen.tableView, didSelectRowAt: IndexPath(row: try index("SORA2", screen), section: 0))
    XCTAssertEqual(calls, 1)
    XCTAssertNil(screen.presentedViewController)
  }
  func testUnavailableLegacyServicesShowReceiveAddressAndExplanation() async throws {
    let f = try make()
    let screen = await portfolio(f)
    screen.tableView(
      screen.tableView, didSelectRowAt: IndexPath(row: try index("SORA2", screen), section: 0))
    let alert = try XCTUnwrap(screen.presentedViewController as? UIAlertController)
    XCTAssertTrue(alert.message?.contains("services are unavailable") == true)
    XCTAssertTrue(alert.message?.contains(f.account.walletId) == true)
  }
  func testTairaReadFailureDisplaysUnavailableRatherThanZero() async throws {
    let f = try make()
    f.read.balanceError = NetworkUIFailure.injected
    let screen = await portfolio(f)
    let row = try index("Taira", screen)
    await wait { self.content(screen, row)?.secondaryText?.contains("Unavailable XOR") == true }
  }
  func testUnavailableLegacyBalanceDoesNotDisplayStaleCachedAmount() async throws {
    let f = try make()
    let b = NetworkUIBalances()
    b.unavailable = true
    let screen = await portfolio(f, balances: b)
    let row = try index("SORA2", screen)
    await wait { f.read.definitionReads > 0 }
    XCTAssertTrue(content(screen, row)?.secondaryText?.contains("Unavailable XOR") == true)
  }
  func testPortfolioBalanceObserverIsReleasedWithScreen() async throws {
    let f = try make()
    let b = NetworkUIBalances()
    var screen: NexusPortfolioViewController? = await portfolio(f, balances: b)
    await wait { f.read.definitionReads > 0 }
    XCTAssertEqual(b.observers, 1)
    navigation.popViewController(animated: false)
    screen = nil
    await wait { b.observers == 0 }
    XCTAssertNil(screen)
  }
  func testProductionRowOpensAnOfflineAddressScreen() async throws {
    let f = try make()
    let screen = await portfolio(f)
    screen.tableView(
      screen.tableView, didSelectRowAt: IndexPath(row: try index("SORA Nexus", screen), section: 0))
    XCTAssertTrue(navigation.topViewController is NexusNetworkDetailViewController)
    XCTAssertNil(navigation.topViewController?.navigationItem.rightBarButtonItem)
  }
  func testWalletChangeClearsPreviousPortfolioRows() async throws {
    let f = try make()
    let screen = await portfolio(f)
    SelectedWalletSettings.shared.commitInternalValue(nil)
    screen.viewWillAppear(false)
    XCTAssertEqual(screen.tableView.numberOfRows(inSection: 0), 0)
  }
  func testQualifiedDetailEnablesSendAfterBalanceAndJournalRead() async throws {
    let f = try make()
    let screen = try open(f)
    await wait { screen.navigationItem.rightBarButtonItem?.isEnabled == true }
    XCTAssertEqual(f.sign.signs, 0)
    XCTAssertTrue(f.transport.requests.isEmpty)
  }
  func testAutomaticSendPresentsFormAfterQualification() async throws {
    let f = try make()
    let (_, form) = try await openForm(f)
    XCTAssertTrue(texts(form.view).contains("Available: 100 XOR"))
    XCTAssertTrue(try button("Review send", form.view).isEnabled)
  }
  func testValidFormProducesExactReviewWithoutSigning() async throws {
    let f = try make()
    let (_, form) = try await openForm(f)
    try fill(form)
    await wait { self.findButton("Confirm and send", form.view) != nil }
    XCTAssertTrue(texts(form.view).contains("3 XOR"))
    XCTAssertTrue(texts(form.view).contains(receiver))
    XCTAssertEqual(f.sign.signs, 0)
  }
  func testInvalidRecipientNeverReachesQuote() async throws {
    let f = try make()
    let (_, form) = try await openForm(f)
    try fill(form, receiver: "bad")
    await wait { self.texts(form.view).contains(where: { $0.contains("Check the recipient") }) }
    XCTAssertEqual(f.sign.quotes, 0)
  }
  func testInsufficientBalanceShowsUnsentReviewError() async throws {
    let f = try make()
    let (_, form) = try await openForm(f)
    try fill(form, amount: "100")
    await wait {
      self.texts(form.view).contains(where: {
        $0.localizedCaseInsensitiveContains("insufficient")
          || $0.localizedCaseInsensitiveContains("enough")
      })
    }
    XCTAssertEqual(f.sign.signs, 0)
  }
  func testConfirmedSendDisplaysCommittedResult() async throws {
    let f = try make()
    let (_, form) = try await openForm(f)
    try fill(form)
    await wait { self.findButton("Confirm and send", form.view) != nil }
    try button("Confirm and send", form.view).sendActions(for: .touchUpInside)
    await wait { self.findButton("View Activity", form.view)?.isHidden == false }
    XCTAssertEqual(f.sign.signs, 1)
    XCTAssertEqual(f.transport.requests.count, 1)
    let rows = try await f.pending.all()
    XCTAssertEqual(rows.first?.state, .committed)
  }
  func testAmbiguousTransportShowsCheckActivityInsteadOfRetry() async throws {
    let f = try make()
    let (_, form) = try await openForm(f)
    try fill(form)
    await wait { self.findButton("Confirm and send", form.view) != nil }
    f.transport.error = NetworkUIFailure.injected
    try button("Confirm and send", form.view).sendActions(for: .touchUpInside)
    await wait { self.findButton("View Activity", form.view)?.isHidden == false }
    XCTAssertEqual(f.transport.requests.count, 1)
    XCTAssertTrue(findButton("Confirm and send", form.view)?.isHidden == true)
  }
  func testChangedFeeReturnsToEditableDraftWithoutTransport() async throws {
    let f = try make()
    let (_, form) = try await openForm(f)
    try fill(form)
    await wait { self.findButton("Confirm and send", form.view) != nil }
    f.sign.fee = "2"
    try button("Confirm and send", form.view).sendActions(for: .touchUpInside)
    await wait { self.findButton("Review send", form.view)?.isHidden == false }
    XCTAssertTrue(f.transport.requests.isEmpty)
    XCTAssertEqual(f.sign.signs, 0)
  }
  func testBalanceFailureKeepsSendDisabled() async throws {
    let f = try make()
    f.read.balanceError = NetworkUIFailure.injected
    let screen = try open(f)
    await wait {
      screen.tableView(screen.tableView, cellForRowAt: IndexPath(row: 0, section: 0)).textLabel?
        .text == "Unavailable XOR"
        || (screen.tableView(screen.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
          .contentConfiguration as? UIListContentConfiguration)?.text == "Unavailable XOR"
    }
    XCTAssertFalse(screen.navigationItem.rightBarButtonItem?.isEnabled ?? true)
  }
}
@MainActor private final class NetworkUISelection {
  var account: NetworkAccount?
  init(_ account: NetworkAccount?) { self.account = account }
}
private enum NetworkUIFailure: Error { case injected }
private final class NetworkUIRead: NexusToriiReading {
  let account: String, receiver: String, asset: String, hash: String
  var quantity = "100", definition: String, historyAmount = "2", statusHash: String
  var definitionReads = 0, statusReads = 0
  var balanceRequests: [String] = []
  var wrongAccount = false, authoritative = true, duplicateHistory = false
  var kind = "applied", resolvedFrom = "state"
  var statusError: Error?
  var balanceError: Error?
  init(account: String, receiver: String, asset: String, hash: String) {
    self.account = account
    self.receiver = receiver
    self.asset = asset
    self.hash = hash
    definition = asset
    statusHash = hash
  }
  func xorAssetDefinition(configuration: NexusNetworkConfiguration) async throws
    -> NexusAssetDefinition
  {
    definitionReads += 1
    return NexusAssetDefinition(id: definition)
  }
  func accountAssets(
    account: String, configuration: NexusNetworkConfiguration, asset: String, limit: Int,
    offset: Int
  ) async throws -> NexusAccountAssetList {
    if let balanceError { throw balanceError }
    balanceRequests.append(account)
    let row: [String: Any] = [
      "account_id": wrongAccount ? receiver : account, "asset": asset, "asset_name": "xor",
      "asset_alias": "xor#universal", "scope": "global",
      "quantity": quantity,
    ]
    return try JSONDecoder().decode(
      NexusAccountAssetList.self,
      from: JSONSerialization.data(withJSONObject: [
        "items": [row], "total": 1, "count_mode": "exact", "has_more": false,
      ]))
  }
  func status(hash: String, configuration: NexusNetworkConfiguration) async throws
    -> NexusPipelineStatus
  {
    statusReads += 1
    if let statusError { throw statusError }
    return try JSONDecoder().decode(
      NexusPipelineStatus.self,
      from: JSONSerialization.data(withJSONObject: [
        "hash": statusHash, "scope": "global", "resolved_from": resolvedFrom,
        "status": ["kind": kind, "block_height": 10],
      ]))
  }
  func hasAuthoritativeCommittedTransaction(
    account: String, configuration: NexusNetworkConfiguration, assetDefinitionID: String,
    transactionHash: String
  ) async throws -> Bool { authoritative }
  func transferHistoryPage(
    account: String, configuration: NexusNetworkConfiguration, assetDefinitionID: String,
    cursor: String?
  ) async throws -> NexusCursorHistoryPage {
    NexusCursorHistoryPage(items: [], sourceItemIDs: [], nextCursor: nil)
  }
  func committedXorTransfers(
    account: String, configuration: NexusNetworkConfiguration, assetDefinitionID: String,
    transactionHash: String
  ) async throws -> [NexusTransferHistoryItem] {
    let item = NexusTransferHistoryItem(
      transactionHash: hash, timestampMilliseconds: 1, amount: try PIQuantity(historyAmount),
      sender: account, receiver: receiver)
    return duplicateHistory ? [item, item] : [item]
  }
}
private final class NetworkUISign: NexusTransactionSigning {
  var qualified = true, quotes = 0, signs = 0
  var hash: String, fee = "1", identity = "reviewed-quote"
  var expiry: Int64? = 100
  var authority: String?, receiver: String?, asset: String?, amount: String?, network: NetworkId?
  var error: Error?
  var onSign: (() async throws -> Void)?
  init(hash: String) { self.hash = hash }
  func isQualified(for configuration: NexusNetworkConfiguration) -> Bool { qualified }
  func quoteTransfer(
    _ request: NexusTransferRequest, assetDefinitionID: String,
    configuration: NexusNetworkConfiguration
  ) async throws -> NexusTransferFeeQuote {
    quotes += 1
    return NexusTransferFeeQuote(
      networkId: network ?? request.networkId, authority: authority ?? request.sender,
      receiver: receiver ?? request.receiver,
      assetDefinitionId: asset ?? assetDefinitionID,
      amount: try amount.map(PIQuantity.init) ?? request.amount, fee: try PIQuantity(fee),
      quoteIdentity: identity, validUntilBlock: expiry)
  }
  func signTransfer(
    _ request: NexusTransferRequest, assetDefinitionID: String, quote: NexusTransferFeeQuote,
    configuration: NexusNetworkConfiguration
  ) async throws -> NexusSignedTransaction {
    signs += 1
    if let error { throw error }
    try await onSign?()
    return NexusSignedTransaction(payload: Data([1, 2, 3]), pipelineHash: hash)
  }
}
private final class NetworkUIFinality: NexusFinalityReading {
  var qualified = true, wrongChain = false, reads = 0
  var height: Int64 = 10
  var error: Error?
  func isQualified(for configuration: NexusNetworkConfiguration) -> Bool { qualified }
  func finalizedCheckpoint(for configuration: NexusNetworkConfiguration) async throws
    -> NexusFinalityCheckpoint
  {
    reads += 1
    if let error { throw error }
    return NexusFinalityCheckpoint(
      networkId: .taira, chainId: wrongChain ? UUID() : configuration.chainId,
      finalizedBlockHeight: height, finalizedBlockHash: String(repeating: "b", count: 64))
  }
}
private final class NetworkUITransport: NexusToriiSubmitting {
  var hash: String, error: Error?
  var requests: [(Data, UUID)] = []
  var onSubmit: (() async throws -> Void)?
  init(hash: String) { self.hash = hash }
  func submit(
    signedNorito: Data, idempotencyKey: UUID, expectedHash: String,
    configuration: NexusNetworkConfiguration
  ) async throws -> NexusToriiSubmissionResult {
    requests.append((signedNorito, idempotencyKey))
    try await onSubmit?()
    if let error { throw error }
    return .applied(NexusTairaAppliedSubmission(hash: hash, blockHeight: 10))
  }
}

private final class NetworkUIBalances: AssetProviderProtocol {
  var unavailable = false, observers = 0
  func getBalances(with assetIds: [String]) -> [BalanceData] {
    [BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 7))]
  }
  func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> {
    unavailable ? Set(assetIds) : []
  }
  func add(observer: AssetProviderObserverProtocol) { observers += 1 }
  func remove(observer: AssetProviderObserverProtocol) { observers -= 1 }
}
