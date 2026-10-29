// SPDX-License-Identifier: Apache-2.0
import CryptoKit
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
  var onBalanceRead: (() async throws -> Void)?
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
    balanceRequests.append(account)
    try await onBalanceRead?()
    if let balanceError { throw balanceError }
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
  var values: [BalanceData]?
  func getBalances(with assetIds: [String]) -> [BalanceData] {
    values ?? [BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 7))]
  }
  func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> {
    unavailable ? Set(assetIds) : []
  }
  func add(observer: AssetProviderObserverProtocol) { observers += 1 }
  func remove(observer: AssetProviderObserverProtocol) { observers -= 1 }
}

final class TairaTransactionSigningCoverageTests: XCTestCase {
    private enum Failure: Error { case locked, offline }

    private final class Fixture {
        let key = try! Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 7, count: 32))
        let recipientKey = try! Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 9, count: 32))
        let configuration = NexusNetworkConfiguration.taira!
        var maxima = ["0.000000001"]
        var requests = [URLRequest]()
        var messages = [(Data, IrohaConnectWalletContext)]()
        var signatures = [Data]()
        var signFailure: Error?
        var transportFailure: Error?
        var invalidSignature = false
        var transportOverride: ((URLRequest) async throws -> Data)?
        var sender: String { try! address(key.publicKey.rawRepresentation) }
        var receiver: String { try! address(recipientKey.publicKey.rawRepresentation) }
        lazy var client = TairaClient(transport: { [unowned self] request, maximum in
            XCTAssertEqual(maximum, 65_536)
            self.requests.append(request)
            if let error = self.transportFailure { throw error }
            if let override = self.transportOverride { return try await override(request) }
            return try self.response(request)
        })
        lazy var signer = TairaTransactionSigner(client: client, signMessage: { [unowned self] message, context in
            self.messages.append((message, context))
            if let error = self.signFailure { throw error }
            let signature = self.invalidSignature ? Data() : try self.key.signature(for: message)
            self.signatures.append(signature)
            return signature
        })
        func address(_ data: Data) throws -> String {
            try IrohaAddressCodec.encode(publicKeyHex: data.map { String(format: "%02x", $0) }.joined(), chainDiscriminant: configuration.i105Discriminant)
        }
        func request(amount: String = "1.25", wallet: String = "local-signer-fixture", receiver: String? = nil, sender: String? = nil, network: NetworkId = .taira) throws -> NexusTransferRequest {
            NexusTransferRequest(walletId: wallet, networkId: network, sender: sender ?? self.sender, receiver: receiver ?? self.receiver, amount: try PIQuantity(amount))
        }
        func body(_ request: URLRequest) throws -> [String: Any] {
            try XCTUnwrap((JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])?["payload"] as? [String: Any])
        }
        func response(_ request: URLRequest) throws -> Data {
            let authority = try XCTUnwrap(body(request)["authority"] as? String)
            let components: [[String: Any]] = maxima.enumerated().map { index, maximum in
                ["kind": ["kind": index == 0 ? "nexus" : "pipeline_gas", "value": NSNull()],
                 "asset_definition_id": TairaClient.xorDefinition, "max_amount": maximum]
            }
            return try JSONSerialization.data(withJSONObject: [
                "intent": ["payer": "authority", "value": ["charge_limits": components, "gas_limit": NSNull()]],
                "observation": ["ledger_time_ms": 1, "next_block_height": 73, "route_dataspace_id": 0],
                "components": components, "capacities": [],
                "decision": ["status": "accepted", "value": ["debit_source": ["kind": "account", "value": authority], "program_revision": NSNull()]]
            ])
        }
        func quote(_ request: NexusTransferRequest? = nil, asset: String = TairaClient.xorDefinition, configuration: NexusNetworkConfiguration? = nil) async throws -> NexusTransferFeeQuote {
            try await signer.quoteTransfer(request ?? self.request(), assetDefinitionID: asset, configuration: configuration ?? self.configuration)
        }
        func sign(_ quote: NexusTransferFeeQuote, request: NexusTransferRequest? = nil, asset: String = TairaClient.xorDefinition, configuration: NexusNetworkConfiguration? = nil) async throws -> NexusSignedTransaction {
            try await signer.signTransfer(request ?? self.request(), assetDefinitionID: asset, quote: quote, configuration: configuration ?? self.configuration)
        }
        func decodedQuote() throws -> TairaClient.Quote {
            let request = try XCTUnwrap(requests.last)
            let payload = try body(request)
            let parsed = try IrohaAddressCodec.parse(sender, expectedDiscriminant: configuration.i105Discriminant)
            let draft = try TairaClient.Draft(authority: sender, authorityHeader: parsed.canonicalHex.hasPrefix("0x") ? parsed.canonicalHex : "0x" + parsed.canonicalHex,
                authorityKey: key.publicKey.rawRepresentation, recipientKey: recipientKey.publicKey.rawRepresentation,
                amount: "1.25", createdAt: XCTUnwrap(payload["creation_time_ms"] as? UInt64), nonce: XCTUnwrap(payload["nonce"] as? UInt32))
            return try TairaClient.decodeQuote(response(request), draft: draft)
        }
    }
    private func expectQuoteChanged(_ operation: () async throws -> Void) async {
        do { try await operation(); XCTFail("Changed or unavailable quote was accepted") }
        catch NexusToriiError.quoteChanged { }
        catch { XCTFail("Unexpected error: \(error)") }
    }
    private func expectWrongNetwork(_ operation: () async throws -> Void) async {
        do { try await operation(); XCTFail("Wrong network or asset was accepted") }
        catch NexusToriiError.wrongWalletOrNetwork { }
        catch { XCTFail("Unexpected error: \(error)") }
    }
    private func fakeQuote(_ f: Fixture) throws -> NexusTransferFeeQuote {
        NexusTransferFeeQuote(networkId: .taira, authority: f.sender, receiver: f.receiver, assetDefinitionId: TairaClient.xorDefinition,
            amount: try PIQuantity("1.25"), fee: try PIQuantity("0"), quoteIdentity: "unquoted", validUntilBlock: nil)
    }

    func testOnlyCurrentLiveTairaConfigurationQualifies() {
        let f = Fixture()
        XCTAssertTrue(f.signer.isQualified(for: f.configuration))
        XCTAssertFalse(f.signer.isQualified(for: .minamoto))
        let wrong = NexusNetworkConfiguration(networkId: .taira, displayName: "wrong", chainId: UUID(), i105Discriminant: f.configuration.i105Discriminant,
            toriiURL: f.configuration.toriiURL, explorerURL: f.configuration.explorerURL, derivationPath: f.configuration.derivationPath, isTestnet: true)
        XCTAssertFalse(f.signer.isQualified(for: wrong))
    }
    func testWrongConfigurationDoesNotSignOrSend() async throws {
        let f = Fixture(); await expectWrongNetwork { _ = try await f.quote(configuration: .minamoto) }
        XCTAssertTrue(f.messages.isEmpty); XCTAssertTrue(f.requests.isEmpty)
    }
    func testWrongRequestNetworkDoesNotSignOrSend() async throws {
        let f = Fixture(); await expectWrongNetwork { _ = try await f.quote(f.request(network: .minamoto)) }
        XCTAssertTrue(f.messages.isEmpty); XCTAssertTrue(f.requests.isEmpty)
    }
    func testWrongAssetDoesNotSignOrSend() async throws {
        let f = Fixture(); await expectWrongNetwork { _ = try await f.quote(asset: "another-asset") }
        XCTAssertTrue(f.messages.isEmpty); XCTAssertTrue(f.requests.isEmpty)
    }
    func testInvalidSenderAndReceiverFailBeforeSigning() async throws {
        for request in [try Fixture().request(sender: "invalid"), try Fixture().request(receiver: "invalid")] {
            let f = Fixture()
            do { _ = try await f.quote(request); XCTFail("Malformed address was accepted") } catch { }
            XCTAssertTrue(f.messages.isEmpty); XCTAssertTrue(f.requests.isEmpty)
        }
    }
    func testQuoteAuthenticatesExactPublicRequestAndWalletContext() async throws {
        let f = Fixture(); let quote = try await f.quote()
        let sent = try XCTUnwrap(f.requests.first); let signed = try XCTUnwrap(f.messages.first)
        XCTAssertEqual(sent.url?.absoluteString, "https://taira.sora.org/v1/fees/quote")
        XCTAssertEqual(sent.httpMethod, "POST"); XCTAssertEqual(sent.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let timestamp = try XCTUnwrap(UInt64(XCTUnwrap(sent.value(forHTTPHeaderField: "X-Iroha-Timestamp-Ms"))))
        let nonce = try XCTUnwrap(sent.value(forHTTPHeaderField: "X-Iroha-Nonce"))
        XCTAssertEqual(signed.0, TairaClient.authMessage(body: try XCTUnwrap(sent.httpBody), timestamp: timestamp, nonce: nonce))
        XCTAssertEqual(signed.1, IrohaConnectWalletContext(walletId: "local-signer-fixture", networkId: .taira, accountId: f.sender, publicKey: f.key.publicKey.rawRepresentation))
        XCTAssertEqual(quote.authority, f.sender); XCTAssertEqual(quote.receiver, f.receiver)
        XCTAssertEqual(quote.amount.rawValue, "1.25"); XCTAssertEqual(quote.fee.rawValue, "0.000000001")
        XCTAssertNil(quote.validUntilBlock)
    }
    func testFeeComponentsAreSummedWithExactNineDigitPrecision() async throws {
        let f = Fixture(); f.maxima = ["1234567890123456789.123456789", "0.876543211"]
        let quote = try await f.quote(); XCTAssertEqual(quote.fee.rawValue, "1234567890123456790")
    }
    func testWholeAndFractionalFeesTrimOnlyInsignificantZeros() async throws {
        let f = Fixture(); f.maxima = ["2.5", "0.00000001"]
        let quote = try await f.quote(); XCTAssertEqual(quote.fee.rawValue, "2.50000001")
    }
    func testEmptyOrZeroFeeComponentsProduceZeroFee() async throws {
        for maxima in [[], ["0"], ["0", "0"]] as [[String]] {
            let f = Fixture(); f.maxima = maxima
            let quote = try await f.quote(); XCTAssertEqual(quote.fee.rawValue, "0")
        }
    }
    func testRepeatedRequestRetainsDraftAndQuoteIdentity() async throws {
        let f = Fixture(); let first = try await f.quote(); let second = try await f.quote()
        XCTAssertEqual(first, second); XCTAssertEqual(f.requests.count, 2)
        XCTAssertEqual(f.requests[0].httpBody, f.requests[1].httpBody)
        XCTAssertEqual(f.messages.count, 2)
    }
    func testFeeChangeReplacesQuoteAndRejectsPreviousIdentity() async throws {
        let f = Fixture(); let first = try await f.quote(); f.maxima = ["0.02"]
        let second = try await f.quote(); XCTAssertNotEqual(first.quoteIdentity, second.quoteIdentity)
        await expectQuoteChanged { _ = try await f.sign(first) }
        let signed = try await f.sign(second); XCTAssertFalse(signed.payload.isEmpty)
    }
    func testSignProducesExactCodecEnvelopeAndPipelineHash() async throws {
        let f = Fixture(); let quote = try await f.quote(); let decoded = try f.decodedQuote()
        let signed = try await f.sign(quote)
        let message = NexusTransferCodec.signingMessage(decoded.payload)
        // CryptoKit may randomize valid Ed25519 signatures; verify the exact result used by the signer.
        let signature = try XCTUnwrap(f.signatures.last)
        XCTAssertTrue(f.key.publicKey.isValidSignature(signature, for: message))
        let expected = try NexusTransferCodec.envelope(payload: decoded.payload, signature: signature, publicKey: f.key.publicKey.rawRepresentation)
        XCTAssertEqual(signed.payload, expected)
        XCTAssertEqual(signed.pipelineHash, NexusTransferCodec.transactionHash(decoded.payload).map { String(format: "%02x", $0) }.joined())
        XCTAssertEqual(f.messages.last?.0, message); XCTAssertEqual(f.messages.last?.1.accountId, f.sender)
        XCTAssertEqual(f.requests.count, 1)
    }
    func testSignedDraftIsConsumedAndCannotSignTwice() async throws {
        let f = Fixture(); let quote = try await f.quote(); _ = try await f.sign(quote)
        await expectQuoteChanged { _ = try await f.sign(quote) }; XCTAssertEqual(f.messages.count, 2)
    }
    func testSigningBeforeQuoteFailsWithoutAccessingKeys() async throws {
        let f = Fixture(); await expectQuoteChanged { _ = try await f.sign(fakeQuote(f)) }
        XCTAssertTrue(f.messages.isEmpty); XCTAssertTrue(f.requests.isEmpty)
    }
    func testSigningWrongRequestAssetOrConfigurationKeepsValidQuote() async throws {
        let f = Fixture(); let quote = try await f.quote()
        await expectQuoteChanged { _ = try await f.sign(quote, request: f.request(amount: "2")) }
        await expectQuoteChanged { _ = try await f.sign(quote, asset: "wrong") }
        await expectQuoteChanged { _ = try await f.sign(quote, configuration: .minamoto) }
        XCTAssertEqual(f.messages.count, 1)
        _ = try await f.sign(quote); XCTAssertEqual(f.messages.count, 2)
    }
    func testNinthDistinctRequestEvictsOldestButRetainsMostRecent() async throws {
        let f = Fixture(); let original = try await f.quote(); var newest = original
        for index in 1...8 { newest = try await f.quote(f.request(amount: String(index + 2))) }
        await expectQuoteChanged { _ = try await f.sign(original) }
        _ = try await f.sign(newest, request: f.request(amount: "10"))
        XCTAssertEqual(f.requests.count, 9)
    }
    func testWalletIdentityIsPartOfCachedRequest() async throws {
        let f = Fixture(); let first = try await f.quote(); let request = try f.request(wallet: "second-wallet")
        let second = try await f.quote(request)
        _ = try await f.sign(first); _ = try await f.sign(second, request: request)
        XCTAssertEqual(f.messages.suffix(2).map { $0.1.walletId }, ["local-signer-fixture", "second-wallet"])
    }
    func testQuoteSignerFailureDoesNotSendAndCanRetry() async throws {
        let f = Fixture(); f.signFailure = Failure.locked
        do { _ = try await f.quote(); XCTFail("Locked keys accepted") } catch Failure.locked { }
        XCTAssertTrue(f.requests.isEmpty)
        f.signFailure = nil; let quote = try await f.quote(); XCTAssertEqual(quote.fee.rawValue, "0.000000001")
    }
    func testInvalidQuoteSignatureDoesNotReachTransport() async throws {
        let f = Fixture(); f.invalidSignature = true
        do { _ = try await f.quote(); XCTFail("Invalid signature accepted") } catch TairaClient.Failure.invalidResponse { }
        XCTAssertTrue(f.requests.isEmpty)
    }
    func testQuoteTransportFailureDoesNotLeaveASignableQuote() async throws {
        let f = Fixture(); f.transportFailure = Failure.offline
        do { _ = try await f.quote(); XCTFail("Transport failure swallowed") } catch Failure.offline { }
        await expectQuoteChanged { _ = try await f.sign(fakeQuote(f)) }
        f.transportFailure = nil; let quote = try await f.quote(); _ = try await f.sign(quote)
        XCTAssertEqual(f.requests.count, 2)
    }
    func testSigningFailureRetainsQuoteForExplicitRetry() async throws {
        let f = Fixture(); let quote = try await f.quote(); f.signFailure = Failure.locked
        do { _ = try await f.sign(quote); XCTFail("Locked keys accepted") } catch Failure.locked { }
        f.signFailure = nil; _ = try await f.sign(quote); XCTAssertEqual(f.requests.count, 1)
    }
    func testInvalidEnvelopeSignatureDoesNotConsumeQuote() async throws {
        let f = Fixture(); let quote = try await f.quote(); f.invalidSignature = true
        do { _ = try await f.sign(quote); XCTFail("Invalid signature accepted") } catch { }
        f.invalidSignature = false; _ = try await f.sign(quote)
    }
    func testLateQuoteCannotRestoreAnEvictedDraft() async throws {
        let f = Fixture(); let entered = expectation(description: "First quote suspended")
        var resume: CheckedContinuation<Void, Never>?
        var first = true
        f.transportOverride = { request in
            if first {
                first = false
                await withCheckedContinuation { continuation in resume = continuation; entered.fulfill() }
            }
            return try f.response(request)
        }
        let task = Task { try await f.quote() }
        await fulfillment(of: [entered], timeout: 2)
        for index in 1...8 { _ = try await f.quote(f.request(amount: String(index + 2))) }
        try XCTUnwrap(resume).resume()
        await expectQuoteChanged { _ = try await task.value }
    }

    func testConfirmationMapsChallengeBoundCheckpointToConfiguredChain() async throws {
        let configuration = try XCTUnwrap(NexusNetworkConfiguration.taira)
        var requests = [URLRequest]()
        let client = TairaClient(transport: { request, maximum in
            requests.append(request)
            if request.url?.path == "/v1/bridge/finality/attestation/latest" {
                XCTAssertEqual(maximum, 8 * 1024 * 1024)
                return try JSONSerialization.data(withJSONObject: ["body": [
                    "challenge": try XCTUnwrap(request.value(forHTTPHeaderField: "X-Iroha-Finality-Challenge")).uppercased(),
                    "network_id": TairaClient.networkLiteral, "genesis_block_hash": TairaClient.networkLiteral,
                    "observed_at_unix_ms": TairaClient.now(), "status": ["applied_height": 73, "committed_height": 74]
                ]])
            }
            XCTAssertEqual(request.url?.path, "/v1/explorer/blocks/73"); XCTAssertEqual(maximum, 65_536)
            return try JSONSerialization.data(withJSONObject: ["height": 73, "hash": TairaClient.networkLiteral])
        })
        let reader = TairaToriiConfirmationReader(client: client)
        let checkpoint = try await reader.finalizedCheckpoint(for: configuration)
        XCTAssertEqual(checkpoint.networkId, .taira); XCTAssertEqual(checkpoint.chainId, configuration.chainId)
        XCTAssertEqual(checkpoint.finalizedBlockHeight, 73)
        XCTAssertEqual(checkpoint.finalizedBlockHash, TairaClient.networkBytes.map { String(format: "%02x", $0) }.joined())
        XCTAssertEqual(requests.count, 2)
    }
    func testConfirmationRejectsNonLiveNetworkWithoutTransport() async throws {
        let reader = TairaToriiConfirmationReader(client: TairaClient(transport: { _, _ in XCTFail("Unqualified confirmation sent"); return Data() }))
        XCTAssertFalse(reader.isQualified(for: .minamoto))
        do { _ = try await reader.finalizedCheckpoint(for: .minamoto); XCTFail("Unqualified confirmation accepted") }
        catch NexusToriiError.finalizedHeadUnavailable { }
    }
    func testConfirmationPreservesTransportFailure() async throws {
        let reader = TairaToriiConfirmationReader(client: TairaClient(transport: { _, _ in throw Failure.offline }))
        do { _ = try await reader.finalizedCheckpoint(for: XCTUnwrap(NexusNetworkConfiguration.taira)); XCTFail("Transport failure swallowed") }
        catch Failure.offline { }
    }
    func testConfirmationRejectsUnboundAttestation() async throws {
        let reader = TairaToriiConfirmationReader(client: TairaClient(transport: { _, _ in Data("{\"body\":{}}".utf8) }))
        do { _ = try await reader.finalizedCheckpoint(for: XCTUnwrap(NexusNetworkConfiguration.taira)); XCTFail("Unbound attestation accepted") }
        catch TairaClient.Failure.wrongNetwork { }
    }
}

extension NexusNetworkFlowTests {
  private func settledPortfolio(_ f: Fixture, balances: NetworkUIBalances? = nil) async throws -> NexusPortfolioViewController {
    let screen = await portfolio(f, balances: balances)
    await wait { self.content(screen, (try? self.index("Taira", screen)) ?? 0)?.secondaryText?.contains("100 XOR") == true }
    return screen
  }
  private func chooseCopy(_ screen: NexusPortfolioViewController) throws {
    let alert = try XCTUnwrap(screen.presentedViewController as? UIAlertController)
    let action = try XCTUnwrap(alert.actions.first { $0.title == "Copy" })
    let block = try XCTUnwrap(action.value(forKey: "handler"))
    unsafeBitCast(block as AnyObject, to: (@convention(block) (UIAlertAction) -> Void).self)(action)
  }
  func testPortfolioCopyUsesTheExactCurrentSoraAddress() async throws {
    let f = try make(); let screen = try await settledPortfolio(f)
    let clipboard = UIPasteboard.general.items
    defer { UIPasteboard.general.items = clipboard }
    screen.tableView(screen.tableView, didSelectRowAt: IndexPath(row: try index("SORA2", screen), section: 0))
    try chooseCopy(screen)
    XCTAssertEqual(UIPasteboard.general.string, f.account.walletId)
  }
  func testRetainedPortfolioCopyCannotExposeThePreviousWalletAfterSelectionChanges() async throws {
    let f = try make(); let screen = try await settledPortfolio(f)
    let clipboard = UIPasteboard.general.items
    defer { UIPasteboard.general.items = clipboard }
    UIPasteboard.general.string = "untouched clipboard"
    screen.tableView(screen.tableView, didSelectRowAt: IndexPath(row: try index("SORA2", screen), section: 0))
    SelectedWalletSettings.shared.commitInternalValue(nil)
    try chooseCopy(screen)
    XCTAssertEqual(UIPasteboard.general.string, "untouched clipboard")
    XCTAssertEqual(screen.tableView.numberOfRows(inSection: 0), 0)
  }
  func testRetainedPortfolioRowCannotNavigateAfterWalletSelectionChanges() async throws {
    let f = try make(); let screen = try await settledPortfolio(f)
    let row = try index("Taira", screen)
    SelectedWalletSettings.shared.commitInternalValue(nil)
    screen.tableView(screen.tableView, didSelectRowAt: IndexPath(row: row, section: 0))
    XCTAssertTrue(navigation.topViewController === screen)
    XCTAssertNil(screen.presentedViewController)
    XCTAssertEqual(screen.tableView.numberOfRows(inSection: 0), 0)
  }
  func testRetainedTairaRowCannotNavigateAfterTestnetIsDisabled() async throws {
    let f = try make(); let screen = try await settledPortfolio(f)
    let row = try index("Taira", screen)
    SettingsManager.shared.isTairaEnabled = false
    screen.tableView(screen.tableView, didSelectRowAt: IndexPath(row: row, section: 0))
    XCTAssertTrue(navigation.topViewController === screen)
    XCTAssertEqual(screen.tableView.numberOfRows(inSection: 0), 0)
  }
  func testLateBalanceCannotRepopulateRowsAfterWalletSelectionChanges() async throws {
    let f = try make()
    f.read.onBalanceRead = { await MainActor.run { SelectedWalletSettings.shared.commitInternalValue(nil) } }
    let screen = NexusPortfolioViewController(assetsProvider: nil, readClient: f.read, networkStore: { f.store })
    navigation.pushViewController(screen, animated: false)
    await wait { !f.read.balanceRequests.isEmpty && screen.tableView.numberOfRows(inSection: 0) == 0 }
    XCTAssertNil(screen.presentedViewController)
  }
  func testLateBalanceFailureCannotPublishThePreviousWalletError() async throws {
    let f = try make()
    f.read.onBalanceRead = {
      await MainActor.run { SelectedWalletSettings.shared.commitInternalValue(nil) }
      throw NetworkUIFailure.injected
    }
    let screen = NexusPortfolioViewController(assetsProvider: nil, readClient: f.read, networkStore: { f.store })
    navigation.pushViewController(screen, animated: false)
    await wait { !f.read.balanceRequests.isEmpty && screen.tableView.numberOfRows(inSection: 0) == 0 }
    XCTAssertNil(screen.presentedViewController)
  }
  func testLateBalanceCannotPublishAfterTestnetWasDisabledDuringTheRead() async throws {
    let f = try make()
    f.read.onBalanceRead = { await MainActor.run { SettingsManager.shared.isTairaEnabled = false } }
    let screen = NexusPortfolioViewController(assetsProvider: nil, readClient: f.read, networkStore: { f.store })
    navigation.pushViewController(screen, animated: false)
    await wait { !f.read.balanceRequests.isEmpty && screen.tableView.numberOfRows(inSection: 0) == 0 }
    XCTAssertNil(screen.presentedViewController)
  }
  func testCancelledPortfolioBalanceDoesNotBecomeAnUnavailableError() async throws {
    let f = try make(); f.read.balanceError = CancellationError()
    let screen = await portfolio(f)
    await wait { !f.read.balanceRequests.isEmpty && screen.refreshControl?.isRefreshing == false }
    XCTAssertTrue(try content(screen, index("Taira", screen))?.secondaryText?.contains("Loading") == true)
    XCTAssertNil(screen.presentedViewController)
  }
  func testCancelledPortfolioStoreLoadEndsRefreshWithoutAnErrorPrompt() async throws {
    let f = try make(); var loads = 0
    let screen = NexusPortfolioViewController(assetsProvider: nil, readClient: f.read, networkStore: {
      loads += 1; throw CancellationError()
    })
    navigation.pushViewController(screen, animated: false)
    await wait { loads == 1 && screen.refreshControl?.isRefreshing == false }
    XCTAssertEqual(screen.tableView.numberOfRows(inSection: 0), 0)
    XCTAssertNil(screen.presentedViewController)
    XCTAssertEqual(f.read.definitionReads, 0)
  }
  func testUnavailablePortfolioStoreExplainsFailureWithoutReadingANetwork() async throws {
    let f = try make()
    let screen = NexusPortfolioViewController(assetsProvider: nil, readClient: f.read, networkStore: { throw NetworkUIFailure.injected })
    navigation.pushViewController(screen, animated: false)
    await wait { screen.presentedViewController != nil }
    XCTAssertEqual((screen.presentedViewController as? UIAlertController)?.title, "Portfolio unavailable")
    XCTAssertEqual(screen.tableView.numberOfRows(inSection: 0), 0)
    XCTAssertEqual(f.read.definitionReads, 0)
  }
  func testMissingPortfolioSnapshotExplainsFailureWithoutInventingZeroBalances() async throws {
    let f = try make(); let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    directories.append(directory)
    let empty = try WalletNetworkStore(baseURL: directory, recoveryGate: f.gate)
    let screen = NexusPortfolioViewController(assetsProvider: nil, readClient: f.read, networkStore: { empty })
    navigation.pushViewController(screen, animated: false)
    await wait { screen.presentedViewController != nil }
    XCTAssertEqual((screen.presentedViewController as? UIAlertController)?.title, "Portfolio unavailable")
    XCTAssertEqual(screen.tableView.numberOfRows(inSection: 0), 0)
    XCTAssertTrue(f.read.balanceRequests.isEmpty)
  }
  func testPullToRefreshReplacesThePortfolioBalanceWithANewRead() async throws {
    let f = try make(); let screen = try await settledPortfolio(f)
    f.read.quantity = "123.000000001"
    screen.refreshControl?.beginRefreshing()
    screen.refreshControl?.sendActions(for: .valueChanged)
    await wait { self.content(screen, (try? self.index("Taira", screen)) ?? 0)?.secondaryText?.contains("123.000000001 XOR") == true }
    XCTAssertFalse(try XCTUnwrap(screen.refreshControl).isRefreshing)
  }
  func testPortfolioForegroundRefreshesTheVisibleScreen() async throws {
    let f = try make(); let screen = try await settledPortfolio(f)
    f.read.quantity = "44"
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    await wait { self.content(screen, (try? self.index("Taira", screen)) ?? 0)?.secondaryText?.contains("44 XOR") == true }
  }
  func testPortfolioBalanceObserverRebuildsTheLegacyBalance() async throws {
    let f = try make(); let balances = NetworkUIBalances(); let screen = try await settledPortfolio(f, balances: balances)
    balances.values = [BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 81))]
    screen.processBalance(data: balances.values!)
    await wait { self.content(screen, (try? self.index("SORA2", screen)) ?? 0)?.secondaryText?.contains("81 XOR") == true }
  }
  func testDuplicateLegacyBalancesAreShownAsUnknown() async throws {
    let f = try make(); let balances = NetworkUIBalances()
    balances.values = (0..<2).map { _ in BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 7)) }
    let screen = try await settledPortfolio(f, balances: balances)
    XCTAssertTrue(try content(screen, index("SORA2", screen))?.secondaryText?.contains("— XOR") == true)
  }
  func testNegativeLegacyBalanceIsShownAsUnknown() async throws {
    let f = try make(); let balances = NetworkUIBalances()
    balances.values = [BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: -1))]
    let screen = try await settledPortfolio(f, balances: balances)
    XCTAssertTrue(try content(screen, index("SORA2", screen))?.secondaryText?.contains("— XOR") == true)
  }
  func testUnrelatedLegacyBalanceCannotBeDisplayedAsXor() async throws {
    let f = try make(); let balances = NetworkUIBalances()
    balances.values = [BalanceData(identifier: "unrelated", balance: AmountDecimal(value: 999))]
    let screen = try await settledPortfolio(f, balances: balances)
    XCTAssertTrue(try content(screen, index("SORA2", screen))?.secondaryText?.contains("— XOR") == true)
  }
}
