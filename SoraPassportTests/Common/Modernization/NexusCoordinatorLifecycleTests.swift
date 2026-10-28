// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import NexusTransferCodec
import SoraKeystore
import XCTest

@testable import SoraPassport

/// Real coordinator and durable journals, with inert transport and signing boundaries.
@MainActor
final class NexusCoordinatorLifecycleTests: XCTestCase {
  private var directories: [URL] = []
  private let sender = "testuﾛ1Q1ﾘﾚxgﾁﾃﾀdRZﾀWｿfXLGﾜﾘPﾐﾉﾉkﾃ7ﾖｶBｹssﾙﾈjｷｹUNYWHP"
  private let receiver = "testuﾛ1NｼXCeｱﾈﾁRｴUﾀPWﾏVｱrﾋhESEbpﾂｾ9Vﾗ5ﾇJｵavsｷ26TMSNN"
  private let asset = NexusAssetDefinitionIdentity.tairaXorDefinitionID
  private let transactionHash = String(repeating: "a", count: 64)
  override func tearDown() {
    for directory in directories { try? FileManager.default.removeItem(at: directory) }
    directories.removeAll()
    super.tearDown()
  }
  private struct Fixture {
    let model: NexusTransactionCoordinator
    let read: CoordinatorRead
    let sign: CoordinatorSign
    let finality: CoordinatorFinality
    let transport: CoordinatorTransport
    let pending: NexusPendingTransactionStore
    let settings: InMemorySettingsManager
    let store: WalletNetworkStore
    let gate: WalletRecoveryCapabilityGate
    let account: NetworkAccount
    let request: NexusTransferRequest
    var selection: CoordinatorSelection
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
    let read = CoordinatorRead(
      account: sender, receiver: receiver, asset: asset, hash: transactionHash)
    let sign = CoordinatorSign(hash: transactionHash)
    let finality = CoordinatorFinality()
    let transport = CoordinatorTransport(hash: transactionHash)
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
      selection: CoordinatorSelection(account))
  }
  private func prepare(_ f: Fixture) async throws -> NexusPreparedTransfer {
    try await f.model.prepare(f.request, selectedAccount: { f.selection.account })
  }
  private func send(_ f: Fixture, _ p: NexusPreparedTransfer) async throws
    -> NexusPendingTransaction
  {
    try await f.model.send(p, selectedAccount: { f.selection.account })
  }
  private func fails<T>(
    _ expected: NexusToriiError? = nil, _ action: () async throws -> T,
    file: StaticString = #filePath, line: UInt = #line
  ) async {
    do {
      _ = try await action()
      XCTFail("Operation unexpectedly succeeded", file: file, line: line)
    } catch {
      if let expected {
        XCTAssertEqual(
          String(describing: error), String(describing: expected), file: file, line: line)
      }
    }
  }
  private func journal(_ f: Fixture) async throws -> [NexusPendingTransaction] {
    try await f.pending.all()
  }
  func testCurrentBalanceBindsExactAssetAndAccount() async throws {
    let f = try make()
    f.read.quantity = "12345678901234567890.123456789"
    let balance = try await f.model.currentXorBalance(account: f.account)
    XCTAssertEqual(balance.quantity.rawValue, f.read.quantity)
    XCTAssertEqual(balance.assetDefinitionID, asset)
    XCTAssertEqual(f.read.balanceRequests, [sender])
    XCTAssertEqual(f.sign.quotes, 0)
  }
  func testBalanceConveniencePreservesExactQuantity() async throws {
    let f = try make()
    let balance = try await f.model.balance(account: f.account)
    XCTAssertEqual(balance.rawValue, "100")
  }
  func testPrepareBindsReviewedAmountFeeAndReceiverWithoutSigning() async throws {
    let f = try make(amount: "2.000000001")
    let p = try await prepare(f)
    XCTAssertEqual(p.request, f.request)
    XCTAssertEqual(p.canonicalReceiver, receiver)
    XCTAssertEqual(p.quote.fee.rawValue, "1")
    XCTAssertEqual(p.availableBalance.rawValue, "100")
    XCTAssertEqual(f.sign.signs, 0)
    XCTAssertEqual(f.transport.requests.count, 0)
    let rows = try await journal(f)
    XCTAssertTrue(rows.isEmpty)
  }
  func testExactAmountPlusFeeMaySpendTheAvailableBalance() async throws {
    let f = try make()
    f.read.quantity = "3"
    _ = try await prepare(f)
  }
  func testPrepareRejectsInsufficientBalanceIncludingFee() async throws {
    let f = try make()
    f.read.quantity = "2.999999999"
    await fails(.insufficientBalance) { try await prepare(f) }
  }
  func testPrepareRejectsMissingSelectedAccountBeforeAnyRead() async throws {
    let f = try make()
    f.selection.account = nil
    await fails(.wrongWalletOrNetwork) { try await prepare(f) }
    XCTAssertEqual(f.read.definitionReads, 0)
  }
  func testPrepareRejectsAnUnqualifiedSigner() async throws {
    let f = try make()
    f.sign.qualified = false
    await fails(.nativeBridgeUnavailable) { try await prepare(f) }
    XCTAssertEqual(f.read.definitionReads, 0)
  }
  func testPrepareRejectsUnqualifiedFinality() async throws {
    let f = try make()
    f.finality.qualified = false
    await fails(.finalizedHeadUnavailable) { try await prepare(f) }
  }
  func testPrepareHonorsTheExplicitTestnetPreference() async throws {
    let f = try make()
    f.settings.isTairaEnabled = false
    await fails(.sendsDisabled) { try await prepare(f) }
    XCTAssertEqual(f.read.definitionReads, 0)
  }
  func testPrepareHonorsNexusAvailability() async throws {
    let f = try make()
    f.settings.nexusEnabled = false
    await fails(.sendsDisabled) { try await prepare(f) }
  }
  func testZeroAmountNeverReachesQuoteOrSigning() async throws {
    let f = try make(amount: "0")
    await fails { try await prepare(f) }
    XCTAssertEqual(f.sign.quotes, 0)
  }
  func testOverprecisionAmountNeverReachesQuote() async throws {
    let f = try make(amount: "0.0000000001")
    await fails { try await prepare(f) }
    XCTAssertEqual(f.sign.quotes, 0)
  }
  func testPrepareRejectsMalformedReceiverBeforeQuote() async throws {
    let f = try make()
    let request = NexusTransferRequest(
      walletId: f.account.walletId, networkId: .taira, sender: sender, receiver: "not-an-address",
      amount: f.request.amount)
    await fails { try await f.model.prepare(request, selectedAccount: { f.account }) }
    XCTAssertEqual(f.sign.quotes, 0)
  }
  func testPrepareRejectsExpiredQuote() async throws {
    let f = try make()
    f.sign.expiry = 9
    f.finality.height = 10
    await fails(.quoteExpired) { try await prepare(f) }
  }
  func testQuoteAtItsLastValidBlockIsAccepted() async throws {
    let f = try make()
    f.sign.expiry = 10
    f.finality.height = 10
    _ = try await prepare(f)
  }
  func testQuoteWithoutBlockExpiryNeedsNoCheckpointRead() async throws {
    let f = try make()
    f.sign.expiry = nil
    _ = try await prepare(f)
    XCTAssertEqual(f.finality.reads, 0)
  }
  func testZeroExpiryIsRejectedAsMalformed() async throws {
    let f = try make()
    f.sign.expiry = 0
    await fails(.invalidResponse) { try await prepare(f) }
  }
  func testQuoteIdentityMustBePresent() async throws {
    let f = try make()
    f.sign.identity = ""
    await fails(.invalidResponse) { try await prepare(f) }
  }
  func testQuoteMustBindTheSender() async throws {
    let f = try make()
    f.sign.authority = receiver
    await fails(.invalidResponse) { try await prepare(f) }
  }
  func testQuoteMustBindTheReceiver() async throws {
    let f = try make()
    f.sign.receiver = sender
    await fails(.invalidResponse) { try await prepare(f) }
  }
  func testQuoteMustBindTheAmount() async throws {
    let f = try make()
    f.sign.amount = "3"
    await fails(.invalidResponse) { try await prepare(f) }
  }
  func testQuoteMustBindTheNetwork() async throws {
    let f = try make()
    f.sign.network = .minamoto
    await fails(.invalidResponse) { try await prepare(f) }
  }
  func testQuoteCannotChangeTheAssetDefinition() async throws {
    let f = try make()
    f.sign.asset = "wrong"
    await fails(.invalidResponse) { try await prepare(f) }
  }
  func testFeeCannotExceedTheAssetScale() async throws {
    let f = try make()
    f.sign.fee = "0.0000000001"
    await fails(.invalidResponse) { try await prepare(f) }
  }
  func testMalformedFinalityCannotAuthorizeAnExpiry() async throws {
    let f = try make()
    f.finality.wrongChain = true
    await fails(.invalidResponse) { try await prepare(f) }
  }
  func testPrepareRejectsDefinitionForAnotherAsset() async throws {
    let f = try make()
    f.read.definition = "bad"
    await fails(.invalidResponse) { try await prepare(f) }
  }
  func testBalanceRejectsContradictoryAccountEvidence() async throws {
    let f = try make()
    f.read.wrongAccount = true
    await fails { try await prepare(f) }
  }
  func testSendPersistsHashBeforeTransportAndReconcilesExactHistory() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.transport.onSubmit = {
      let rows = try await f.pending.all()
      XCTAssertEqual(rows.first?.state, .submitting)
      XCTAssertEqual(rows.first?.hash, self.transactionHash)
    }
    let result = try await send(f, p)
    XCTAssertEqual(result.state, .committed)
    XCTAssertNotNil(result.historyReconciledAt)
    XCTAssertEqual(result.terminalBlockHeight, 10)
    XCTAssertEqual(result.sender, sender)
    XCTAssertEqual(result.receiver, receiver)
    XCTAssertEqual(result.amount.rawValue, "2")
    XCTAssertTrue(p.submissionMayHaveStarted)
    XCTAssertEqual(f.sign.signs, 1)
    XCTAssertEqual(f.transport.requests.count, 1)
    XCTAssertEqual(f.transport.requests.first?.0, Data([1, 2, 3]))
    XCTAssertEqual(f.transport.requests.first?.1, result.idempotencyKey)
    let rows = try await journal(f)
    XCTAssertEqual(rows, [result])
  }
  func testReviewedConfirmationCanOnlyBeSubmittedOnce() async throws {
    let f = try make()
    let p = try await prepare(f)
    _ = try await send(f, p)
    await fails(.confirmationAlreadySubmitted) { try await send(f, p) }
    XCTAssertEqual(f.transport.requests.count, 1)
  }
  func testChangedFeeRequiresANewReviewBeforeSigning() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.sign.fee = "2"
    await fails(.quoteChanged) { try await send(f, p) }
    XCTAssertEqual(f.sign.signs, 0)
    XCTAssertFalse(p.submissionMayHaveStarted)
  }
  func testChangedQuoteIdentityRequiresANewReview() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.sign.identity = "new"
    await fails(.quoteChanged) { try await send(f, p) }
    XCTAssertEqual(f.transport.requests.count, 0)
  }
  func testChangedQuoteExpiryRequiresANewReview() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.sign.expiry = 101
    await fails(.quoteChanged) { try await send(f, p) }
  }
  func testBalanceIsRereadBeforeSigning() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.read.quantity = "1"
    await fails(.insufficientBalance) { try await send(f, p) }
    XCTAssertEqual(f.sign.signs, 0)
  }
  func testDeselectionBetweenReviewAndConfirmPreventsSubmission() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.selection.account = nil
    await fails(.wrongWalletOrNetwork) { try await send(f, p) }
    XCTAssertEqual(f.sign.signs, 0)
  }
  func testQuoteExpiringAfterReviewCannotBeSigned() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.finality.height = 101
    await fails(.quoteExpired) { try await send(f, p) }
    XCTAssertEqual(f.sign.signs, 0)
  }
  func testWalletRemovedFromDurableStoreCannotBeSigned() async throws {
    let f = try make()
    let p = try await prepare(f)
    try f.store.recordExplicitRemoval(
      walletId: f.account.walletId, expectedWalletIds: [f.account.walletId],
      selectedWalletId: f.account.walletId)
    await fails(.wrongWalletOrNetwork) { try await send(f, p) }
    XCTAssertEqual(f.sign.signs, 0)
    let rows = try await journal(f)
    XCTAssertTrue(rows.isEmpty)
  }
  func testSignerFailureClosesPreSignRecordWithoutTransport() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.sign.error = CoordinatorFailure.injected
    await fails { try await send(f, p) }
    let rows = try await journal(f)
    XCTAssertEqual(rows.first?.state, .failedBeforeSubmission)
    XCTAssertNil(rows.first?.hash)
    XCTAssertFalse(p.submissionMayHaveStarted)
  }
  func testMalformedSignerHashCannotReachTransport() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.sign.hash = "bad"
    await fails(.invalidResponse) { try await send(f, p) }
    XCTAssertEqual(f.transport.requests.count, 0)
    let rows = try await journal(f)
    XCTAssertEqual(rows.first?.state, .failedBeforeSubmission)
  }
  func testWalletSwitchDuringSigningLeavesDefinitiveFailure() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.sign.onSign = { await MainActor.run { f.selection.account = nil } }
    await fails(.wrongWalletOrNetwork) { try await send(f, p) }
    XCTAssertEqual(f.transport.requests.count, 0)
    let rows = try await journal(f)
    XCTAssertEqual(rows.first?.state, .failedBeforeSubmission)
  }
  func testTransportDisconnectRemainsAmbiguousAndCannotBeResubmitted() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.transport.error = CoordinatorFailure.injected
    await fails(.ambiguousSubmission) { try await send(f, p) }
    XCTAssertTrue(p.submissionMayHaveStarted)
    let rows = try await journal(f)
    XCTAssertEqual(rows.first?.state, .submissionUnknown)
    XCTAssertEqual(rows.first?.hash, transactionHash)
    await fails(.confirmationAlreadySubmitted) { try await send(f, p) }
    XCTAssertEqual(f.sign.signs, 1)
  }
  func testContradictoryTransportHashRemainsRecoverable() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.transport.hash = String(repeating: "b", count: 64)
    await fails(.transactionHashMismatch) { try await send(f, p) }
    let rows = try await journal(f)
    XCTAssertEqual(rows.first?.state, .submissionUnknown)
  }
  func testStatusReadFailureRetainsAppliedButUnreconciledEvidence() async throws {
    let f = try make()
    let p = try await prepare(f)
    f.read.statusError = CoordinatorFailure.injected
    let result = try await send(f, p)
    XCTAssertEqual(result.state, .committedPendingReconciliation)
    XCTAssertNil(result.historyReconciledAt)
  }
  func testRecoveryDoesNotCloseARecordOwnedByTheLiveSigner() async throws {
    let f = try make()
    let p = try await prepare(f)
    let started = expectation(description: "signer started")
    var continuation: CheckedContinuation<Void, Never>?
    f.sign.onSign = {
      await withCheckedContinuation { pending in
        continuation = pending
        started.fulfill()
      }
    }
    let sendTask = Task { try await send(f, p) }
    await fulfillment(of: [started], timeout: 2)
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows.first?.state, .signing)
    XCTAssertEqual(f.read.statusReads, 0)
    continuation?.resume()
    let result = try await sendTask.value
    XCTAssertEqual(result.state, .committed)
  }
  func testUnreadableJournalPreventsQuoteAndSigning() async throws {
    let f = try make()
    let directory = try XCTUnwrap(directories.last)
    let journal = directory.appendingPathComponent("SORA/PendingTransactions/nexus-v1.json")
    try Data("broken".utf8).write(to: journal)
    await fails { try await prepare(f) }
    XCTAssertEqual(f.sign.quotes, 0)
    XCTAssertEqual(f.read.definitionReads, 0)
  }
  private func seed(
    _ f: Fixture, state: NexusPendingState = .submissionUnknown, hash: String? = nil,
    includeHash: Bool = true
  ) async throws -> NexusPendingTransaction {
    let config = NexusNetworkConfiguration.taira!
    let row = NexusPendingTransaction(
      id: UUID(), idempotencyKey: UUID(), walletId: f.account.walletId, networkId: .taira,
      chainId: config.chainId,
      tairaDeployment: NexusPendingTairaDeploymentIdentity.admitted(for: config),
      signingNetworkId: TairaClient.networkLiteral,
      sender: sender, receiver: receiver, assetDefinitionID: asset, amount: try PIQuantity("2"),
      fee: try PIQuantity("1"),
      createdAt: Date(), updatedAt: Date(),
      hash: includeHash ? (hash ?? self.transactionHash) : nil,
      state: state, terminalBlockHeight: nil, errorClass: nil, historyReconciledAt: nil)
    return try await f.pending.put(row)
  }
  func testRecoveryReconcilesWithoutQuotingSigningOrResubmitting() async throws {
    let f = try make()
    _ = try await seed(f)
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows.first?.state, .committed)
    XCTAssertNotNil(rows.first?.historyReconciledAt)
    XCTAssertEqual(f.sign.quotes, 0)
    XCTAssertEqual(f.sign.signs, 0)
    XCTAssertEqual(f.transport.requests.count, 0)
  }
  func testRecoveryClosesInterruptedPreSignMarkerWithoutNetwork() async throws {
    let f = try make()
    _ = try await seed(f, state: .signing, includeHash: false)
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows.first?.state, .failedBeforeSubmission)
    XCTAssertEqual(rows.first?.errorClass, "interrupted_before_submission")
    XCTAssertEqual(f.read.statusReads, 0)
  }
  func testTerminalFailureIsNeverReopenedByRecovery() async throws {
    let f = try make()
    _ = try await seed(f, state: .rejected)
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows.first?.state, .rejected)
    XCTAssertEqual(f.read.statusReads, 0)
  }
  func testAuthoritativeRejectionIsPersisted() async throws {
    let f = try make()
    _ = try await seed(f)
    f.read.kind = "rejected"
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows.first?.state, .rejected)
  }
  func testAuthoritativeExpiryIsPersisted() async throws {
    let f = try make()
    _ = try await seed(f)
    f.read.kind = "expired"
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows.first?.state, .expired)
  }
  func testApprovedStatusRemainsRecoverable() async throws {
    let f = try make()
    _ = try await seed(f)
    f.read.kind = "approved"
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows.first?.state, .approved)
    XCTAssertNil(rows.first?.historyReconciledAt)
  }
  func testQueuedStatusRemainsSubmitted() async throws {
    let f = try make()
    _ = try await seed(f)
    f.read.kind = "queued"
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows.first?.state, .submitted)
  }
  func testCachedFailureCannotBecomeTerminal() async throws {
    let f = try make()
    let before = try await seed(f)
    f.read.kind = "rejected"
    f.read.resolvedFrom = "cache"
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows, [before])
  }
  func testWrongStatusHashCannotResolveJournal() async throws {
    let f = try make()
    let before = try await seed(f)
    f.read.statusHash = String(repeating: "b", count: 64)
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows, [before])
  }
  func testUnfinalizedCommitRemainsPendingReconciliation() async throws {
    let f = try make()
    _ = try await seed(f)
    f.finality.height = 9
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows.first?.state, .committedPendingReconciliation)
    XCTAssertNil(rows.first?.historyReconciledAt)
  }
  func testMissingAuthoritativeHistoryDoesNotCompleteTransfer() async throws {
    let f = try make()
    _ = try await seed(f)
    f.read.authoritative = false
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows.first?.state, .committedPendingReconciliation)
  }
  func testWrongHistoryAmountDoesNotCompleteTransfer() async throws {
    let f = try make()
    _ = try await seed(f)
    f.read.historyAmount = "3"
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows.first?.state, .committedPendingReconciliation)
  }
  func testDuplicateHistoryDoesNotCompleteTransfer() async throws {
    let f = try make()
    _ = try await seed(f)
    f.read.duplicateHistory = true
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows.first?.state, .committedPendingReconciliation)
  }
  func testTransientStatusFailurePreservesTheExactStoredRecord() async throws {
    let f = try make()
    let before = try await seed(f)
    f.read.statusError = CoordinatorFailure.injected
    let rows = try await f.model.resumePending()
    XCTAssertEqual(rows, [before])
    XCTAssertEqual(f.sign.signs, 0)
  }
  func testRecoveryPropagatesStatusCancellation() async throws {
    let f = try make()
    _ = try await seed(f)
    f.read.statusError = CancellationError()
    do {
      _ = try await f.model.resumePending()
      XCTFail("Cancellation was swallowed")
    } catch { XCTAssertTrue(error is CancellationError) }
  }
  func testRecoveryPropagatesFinalityCancellation() async throws {
    let f = try make()
    _ = try await seed(f)
    f.finality.error = CancellationError()
    do {
      _ = try await f.model.resumePending()
      XCTFail("Cancellation was swallowed")
    } catch { XCTAssertTrue(error is CancellationError) }
  }
  func testCancelledPrepareNeverPublishesAReview() async throws {
    let f = try make()
    let task = Task { try await prepare(f) }
    task.cancel()
    do {
      _ = try await task.value
      XCTFail("Cancelled preparation returned a review")
    } catch { XCTAssertTrue(error is CancellationError) }
  }
}
@MainActor private final class CoordinatorSelection {
  var account: NetworkAccount?
  init(_ account: NetworkAccount?) { self.account = account }
}
private enum CoordinatorFailure: Error { case injected }
private final class CoordinatorRead: NexusToriiReading {
  let account: String, receiver: String, asset: String, hash: String
  var quantity = "100", definition: String, historyAmount = "2", statusHash: String
  var definitionReads = 0, statusReads = 0
  var balanceRequests: [String] = []
  var wrongAccount = false, authoritative = true, duplicateHistory = false
  var kind = "applied", resolvedFrom = "state"
  var statusError: Error?
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
    let row: [String: Any] = [
      "account_id": wrongAccount ? receiver : account, "asset": asset, "asset_name": "xor", "asset_alias": "xor#universal", "scope": "global",
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
private final class CoordinatorSign: NexusTransactionSigning {
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
private final class CoordinatorFinality: NexusFinalityReading {
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
private final class CoordinatorTransport: NexusToriiSubmitting {
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
