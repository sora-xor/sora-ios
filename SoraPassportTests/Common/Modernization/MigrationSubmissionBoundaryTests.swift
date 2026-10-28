// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraFoundation
import SoraKeystore
import XCTest

@testable import SoraPassport

/// Actual migration orchestration with public fixture entropy and a recording
/// extrinsic boundary. Neither a SORA2 signer nor a transport is invoked.
@MainActor
final class MigrationSubmissionBoundaryTests: XCTestCase {
  private var previous: AccountItem?, directory: URL!, session: URLSession!
  private var service: SubmissionBoundaryService!, events: SubmissionBoundaryEvents!
  private var settings: InMemorySettingsManager!, keys: InMemoryKeychain!, account: AccountItem!
  private var store: Sora2PendingSubmissionStore!, submissions: MigrationSubmitRecorder!
  private let journalReads = MigrationJournalReads()
  private let transactionHash = String(repeating: "ab", count: 32)
  override func setUpWithError() throws {
    previous = SelectedWalletSettings.shared.currentAccount
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SubmissionBoundaryURLProtocol.self]
    session = URLSession(configuration: configuration)
    SubmissionBoundaryURLProtocol.reset()
    SubmissionBoundaryURLProtocol.result = true
    let key = Data(repeating: 0x44, count: 32)
    let address = try SS58AddressFactory().addressFromAccountId(
      data: key, type: ApplicationConfig.shared.addressType)
    account = AccountItem(
      address: address, cryptoType: .sr25519, networkType: 69, username: "Public fixture",
      publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
      order: 0, isSelected: true)
    SelectedWalletSettings.shared.commitInternalValue(account)
    keys = InMemoryKeychain()
    try keys.saveEntropy(Data(repeating: 0, count: 16), address: address)
    settings = InMemorySettingsManager()
    events = SubmissionBoundaryEvents()
    store = try Sora2PendingSubmissionStore(baseURL: directory)
    submissions = MigrationSubmitRecorder()
    journalReads.reset()
    let isolatedStore = store!
    let recorder = submissions!
    let reads = journalReads
    service = SubmissionBoundaryService(
      eventCenter: events, keystore: keys, settings: settings,
      operationManager: OperationManager(), logger: Logger.shared,
      pendingStore: { try reads.read(isolatedStore) },
      extrinsicFactory: { account, _, _, _ in
        recorder.accounts.append(account)
        return recorder
      })
    service.testEngine = Sora2BoundedHTTPJSONRPCEngine(
      nodeURL: URL(string: "https://migration-submit.test")!, session: session)
    service.testRuntime = SubmissionBoundaryRuntime()
  }
  override func tearDownWithError() throws {
    service = nil
    submissions = nil
    session.invalidateAndCancel()
    session = nil
    SubmissionBoundaryURLProtocol.reset()
    SelectedWalletSettings.shared.commitInternalValue(previous)
    try? FileManager.default.removeItem(at: directory)
    directory = nil
    keys = nil
    settings = nil
    events = nil
    store = nil
  }
  private func settle(_ predicate: @escaping () -> Bool = { false }) async {
    for _ in 0..<100 {
      if predicate() { return }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
  }
  private func request() async -> Result<String, Swift.Error>? {
    var value: Result<String, Swift.Error>?
    service.requestMigration { value = $0 }
    await settle { value != nil }
    return value
  }
  private func failure(
    _ result: Result<String, Swift.Error>?, file: StaticString = #filePath, line: UInt = #line
  ) {
    guard case .failure? = result else {
      return XCTFail("Migration must complete with failure", file: file, line: line)
    }
  }
  func testSubmissionBuildsOneMigrationCallForTheDerivedIdentity() async throws {
    failure(await request())
    let encoded = try XCTUnwrap(submissions.builder.calls.first)
    let call = try encoded.map(to: RuntimeCall<MigrateCall>.self)
    XCTAssertEqual(call.moduleName, "IrohaMigration")
    XCTAssertEqual(call.callName, "migrate")
    let params = try XCTUnwrap(SubmissionBoundaryURLProtocol.parameters.first as? [String])
    XCTAssertEqual(call.args.irohaAddress, params.first)
    let phrase = try IRMnemonicCreator().mnemonic(fromEntropy: Data(repeating: 0, count: 16))
    let pair = try IRKeypairFacade().deriveKeypair(from: phrase.toString())
    XCTAssertEqual(call.args.irohaPublicKey, pair.publicKey().rawData().toHex())
    XCTAssertEqual(try Data(hexStringSSF: call.args.irohaSignature).count, 64)
    XCTAssertEqual(submissions.builder.calls.count, 1)
  }
  func testSubmissionPreservesLegacyMigrationPurposeAndMainCallbackQueue() async {
    failure(await request())
    XCTAssertEqual(submissions.purposes, [.legacyMigration])
    XCTAssertEqual(submissions.queues, [DispatchQueue.main.label])
    XCTAssertEqual(submissions.leaseCount, 0)
    XCTAssertTrue(submissions.signers.first is LifecycleSigningWrapperProtocol)
  }
  func testSubmissionUsesTheCapturedSelectedAccount() async {
    failure(await request())
    XCTAssertEqual(submissions.accounts.first?.address, account.address)
    XCTAssertEqual(submissions.accounts.first?.cryptoType, account.cryptoType)
  }
  func testDefiniteSubmissionFailureDoesNotPublishSuccessOrChangeCompletionMarkers() async {
    failure(await request())
    XCTAssertFalse(settings.hasMigrated)
    XCTAssertTrue(events.values.isEmpty)
    XCTAssertEqual(journalReads.count, 1)
  }
  func testDefiniteSubmissionFailurePreservesItsError() async {
    guard case .failure(let error)? = await request() else {
      return XCTFail("Expected transport boundary failure")
    }
    XCTAssertEqual(error as? MigrationSubmitBoundaryError, .offline)
  }
  func testFailedSubmissionCanBeRequestedAgain() async {
    failure(await request())
    failure(await request())
    XCTAssertEqual(submissions.purposes.count, 2)
    XCTAssertEqual(SubmissionBoundaryURLProtocol.methods.count, 2)
  }
  func testInvalidReturnedHashCompletesInsteadOfLeavingTheClaimBusy() async {
    submissions.result = .success("not a hash")
    submissions.callbackHash = transactionHash
    failure(await request())
    XCTAssertEqual(journalReads.count, 1)
  }
  func testMissingCallbackHashCompletesInsteadOfLeavingTheClaimBusy() async {
    submissions.result = .success(transactionHash)
    submissions.callbackHash = nil
    failure(await request())
    XCTAssertEqual(journalReads.count, 1)
  }
  func testDifferentCallbackHashCannotClaimTheReturnedTransaction() async {
    submissions.result = .success(transactionHash)
    submissions.callbackHash = String(repeating: "cd", count: 32)
    failure(await request())
    XCTAssertEqual(journalReads.count, 1)
  }
  func testMalformedCallbackHashCannotClaimTheReturnedTransaction() async {
    submissions.result = .success(transactionHash)
    submissions.callbackHash = "0x01"
    failure(await request())
    XCTAssertEqual(journalReads.count, 1)
  }
  func testPreSigningValidationRejectsAnAccountChangedAtTheBoundary() async {
    submissions.beforeValidation = { SelectedWalletSettings.shared.commitInternalValue(nil) }
    failure(await request())
    XCTAssertTrue(submissions.builder.calls.isEmpty)
  }
  func testPreSigningValidationRejectsAnInvalidatedEligibilityToken() async {
    submissions.beforeValidation = { [weak self] in
      self?.service.testEngine = nil
      self?.service.checkMigration()
    }
    failure(await request())
    XCTAssertTrue(submissions.builder.calls.isEmpty)
  }
  func testConcurrentClaimDuringHeldSubmissionDoesNotResubmit() async {
    submissions.hold = true
    var first: Result<String, Swift.Error>?
    service.requestMigration { first = $0 }
    await settle { self.submissions.purposes.count == 1 }
    failure(await request())
    XCTAssertEqual(submissions.purposes.count, 1)
    submissions.finish()
    await settle { first != nil }
    failure(first)
  }
  func testSubmissionOnlyReadsTheExistingPublicFixtureKeyMaterial() async throws {
    let ids = try keys.allKeyIdentifiers()
    let before = try Dictionary(uniqueKeysWithValues: ids.map { ($0, try keys.fetchKey(for: $0)) })
    failure(await request())
    XCTAssertEqual(try keys.allKeyIdentifiers().sorted(), ids.sorted())
    for (id, value) in before { XCTAssertEqual(try keys.fetchKey(for: id), value) }
  }
  func testPendingJournalFailurePreventsEligibilityAndSubmission() async {
    journalReads.failAfter = 0
    failure(await request())
    XCTAssertTrue(SubmissionBoundaryURLProtocol.methods.isEmpty)
    XCTAssertTrue(submissions.purposes.isEmpty)
  }
  func testMigrationWithoutRecoveryWitnessBlocksBeforeEligibility() async throws {
    _ = try store.stage(account: account.address, hash: transactionHash, purpose: .legacyMigration)
    failure(await request())
    XCTAssertTrue(SubmissionBoundaryURLProtocol.methods.isEmpty)
  }
  func testUnadmittedMigrationCannotBePresentedAsRetrySafe() async throws {
    _ = try store.stage(
      account: account.address, hash: transactionHash, retainingTransportWitness: true,
      purpose: .legacyMigration)
    failure(await request())
    XCTAssertTrue(SubmissionBoundaryURLProtocol.methods.isEmpty)
    XCTAssertEqual(try store.all().count, 1)
  }
  func testAnotherWalletMigrationDoesNotBlockThisWalletEligibility() async throws {
    _ = try store.stage(account: "other-wallet", hash: transactionHash, purpose: .legacyMigration)
    failure(await request())
    XCTAssertEqual(SubmissionBoundaryURLProtocol.methods.count, 1)
    XCTAssertEqual(submissions.purposes.count, 1)
    XCTAssertEqual(try store.all().count, 1)
  }
  func testGenericSubmissionDoesNotBecomeAMigrationCompletion() async throws {
    _ = try store.stage(account: account.address, hash: transactionHash, purpose: .generic)
    failure(await request())
    XCTAssertEqual(submissions.purposes.count, 1)
    XCTAssertFalse(settings.hasMigrated)
  }
  private func witnessedPending(_ byte: String = "ab") throws -> Sora2PendingSubmission {
    let hash = String(repeating: byte, count: 32)
    let context = try Sora2SubmissionRecoveryContext.make(
      walletId: account.address, accountId: account.publicKeyData, publicKey: account.publicKeyData,
      transactionHash: hash, genesisHash: PIIndexerClient.soraMainnetGenesis,
      specVersion: 130, transactionVersion: 130, metadataSHA256: String(repeating: "cd", count: 32),
      era: .mortal(period: 64, phase: 0), eraBirthBlock: 128,
      eraBirthBlockHash: String(repeating: "ef", count: 32))
    return try store.stage(
      account: account.address, hash: hash, recoveryContext: context, purpose: .legacyMigration)
  }
  private func resolve(_ pending: Sora2PendingSubmission, succeeded: Bool) throws {
    try store.resolveAuthoritatively(
      pending,
      proof: .finalizedInclusion(
        blockNumber: 130, blockHash: String(repeating: "bc", count: 32), succeeded: succeeded,
        finalizedHeight: 192))
  }
  func testAuthoritativelyFinalizedMigrationCompletesWithoutEligibilityOrSigning() async throws {
    let pending = try witnessedPending()
    try resolve(pending, succeeded: true)
    guard case .success? = await request() else {
      return XCTFail("Finalized migration must complete")
    }
    XCTAssertTrue(settings.hasMigrated)
    XCTAssertTrue(events.values.first is MigrationSuccsessEvent)
    XCTAssertTrue(SubmissionBoundaryURLProtocol.methods.isEmpty)
    XCTAssertTrue(submissions.purposes.isEmpty)
  }
  func testAuthoritativeFailedMigrationAllowsANewEligibilityCheck() async throws {
    let pending = try witnessedPending()
    try resolve(pending, succeeded: false)
    failure(await request())
    XCTAssertEqual(SubmissionBoundaryURLProtocol.methods.count, 1)
    XCTAssertEqual(submissions.purposes.count, 1)
    XCTAssertFalse(settings.hasMigrated)
  }
  func testMultipleUnresolvedMigrationWitnessesBlockBeforeEligibility() async throws {
    _ = try witnessedPending()
    _ = try witnessedPending("ac")
    failure(await request())
    XCTAssertTrue(SubmissionBoundaryURLProtocol.methods.isEmpty)
    XCTAssertTrue(submissions.purposes.isEmpty)
    XCTAssertEqual(try store.all().count, 2)
  }
  func testResumedFinalityReadsTheInjectedJournalAndPublishesSuccess() async throws {
    let pending = try witnessedPending()
    let isolated = store!
    journalReads.afterFirst = {
      try isolated.resolveAuthoritatively(
        pending,
        proof: .finalizedInclusion(
          blockNumber: 130, blockHash: String(repeating: "bc", count: 32), succeeded: true,
          finalizedHeight: 192))
    }
    guard case .success? = await request() else {
      return XCTFail("Recovered finality must complete")
    }
    XCTAssertEqual(journalReads.count, 2)
    XCTAssertTrue(settings.hasMigrated)
    XCTAssertTrue(submissions.purposes.isEmpty)
    XCTAssertTrue(SubmissionBoundaryURLProtocol.methods.isEmpty)
  }
  func testResumedFinalityDispatchFailureCompletesAsConfirmationFailure() async throws {
    let pending = try witnessedPending()
    let isolated = store!
    journalReads.afterFirst = {
      try isolated.resolveAuthoritatively(
        pending,
        proof: .finalizedInclusion(
          blockNumber: 130, blockHash: String(repeating: "bc", count: 32), succeeded: false,
          finalizedHeight: 192))
    }
    guard case .failure(let error)? = await request() else {
      return XCTFail("Failed dispatch must complete")
    }
    XCTAssertEqual(
      String(describing: error), String(describing: MigrationServiceError.confirmMigrationFail))
    XCTAssertFalse(settings.hasMigrated)
    XCTAssertTrue(events.values.isEmpty)
    XCTAssertTrue(submissions.purposes.isEmpty)
  }
  func testResumedFinalityExpiryCompletesAsRetrySafeFailure() async throws {
    let pending = try witnessedPending()
    let isolated = store!
    journalReads.afterFirst = {
      try isolated.resolveAuthoritatively(
        pending,
        proof: .mortalEraAbsence(
          scannedBirthBlock: 128, scannedDeathBlockExclusive: 192, finalizedHeight: 192))
    }
    guard case .failure(let error)? = await request() else {
      return XCTFail("Expired migration must complete")
    }
    XCTAssertEqual(
      String(describing: error), String(describing: MigrationServiceError.confirmMigrationFail))
    XCTAssertFalse(settings.hasMigrated)
    XCTAssertTrue(submissions.purposes.isEmpty)
  }
  func testBackgroundFinalityFailureOffersRetryWithoutAnotherSubmission() async throws {
    let pending = try witnessedPending()
    let isolated = store!
    journalReads.afterFirst = {
      try isolated.resolveAuthoritatively(
        pending,
        proof: .finalizedInclusion(
          blockNumber: 130, blockHash: String(repeating: "bc", count: 32), succeeded: false,
          finalizedHeight: 192))
    }
    service.checkMigration()
    await settle { !self.events.values.isEmpty }
    XCTAssertTrue(events.values.first is MigrationEvent)
    XCTAssertFalse(settings.hasMigrated)
    XCTAssertTrue(submissions.purposes.isEmpty)
    XCTAssertTrue(SubmissionBoundaryURLProtocol.methods.isEmpty)
  }
  // These recovery tests run only with the pendingStore routing fix. Opening
  // the app's default journal is never an acceptable way to reproduce it.
  func testAcceptedHashUsesTheInjectedJournalForFinalityRecovery() async {
    submissions.result = .success(transactionHash)
    submissions.callbackHash = transactionHash
    failure(await request())
    XCTAssertEqual(journalReads.count, 2)
    XCTAssertFalse(settings.hasMigrated)
    XCTAssertTrue(events.values.isEmpty)
  }
  func testCanonicalHashComparisonAcceptsEquivalentPrefixAndCase() async {
    submissions.result = .success("0x" + transactionHash.uppercased())
    submissions.callbackHash = transactionHash
    failure(await request())
    XCTAssertEqual(journalReads.count, 2)
  }
  func testRecoveryJournalFactoryFailureCompletesTheAttachedClaim() async {
    journalReads.failAfter = 1
    submissions.result = .success(transactionHash)
    submissions.callbackHash = transactionHash
    failure(await request())
    XCTAssertEqual(journalReads.count, 2)
    XCTAssertFalse(settings.hasMigrated)
  }
  func testAmbiguousTransportUsesItsExactLocalHashForRecovery() async {
    submissions.result = .failure(
      PreparedExtrinsicTransportError.submissionUnknown(
        localHash: transactionHash, error: MigrationSubmitBoundaryError.offline))
    submissions.callbackHash = "0x" + transactionHash.uppercased()
    failure(await request())
    XCTAssertEqual(journalReads.count, 2)
  }
  func testAmbiguityWithDifferentCallbackHashCannotEnterRecovery() async {
    submissions.result = .failure(
      PreparedExtrinsicTransportError.submissionUnknown(
        localHash: transactionHash, error: MigrationSubmitBoundaryError.offline))
    submissions.callbackHash = String(repeating: "cd", count: 32)
    failure(await request())
    XCTAssertEqual(journalReads.count, 1)
  }
  func testUnqualifiedAmbiguousErrorCannotInventALocalHash() async {
    submissions.result = .failure(
      PreparedExtrinsicTransportError.submissionUnknown(MigrationSubmitBoundaryError.offline))
    submissions.callbackHash = transactionHash
    failure(await request())
    XCTAssertEqual(journalReads.count, 1)
  }
}
private enum MigrationSubmitBoundaryError: Error, Equatable { case offline, unexpected }
private final class MigrationJournalReads: @unchecked Sendable {
  private let lock = NSLock()
  private var reads = 0
  var failAfter = Int.max
  var afterFirst: (() throws -> Void)?
  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return reads
  }
  func reset() {
    lock.lock()
    reads = 0
    failAfter = Int.max
    lock.unlock()
  }
  func read(_ store: Sora2PendingSubmissionStore) throws -> Sora2PendingSubmissionStore {
    lock.lock()
    reads += 1
    let fails = reads > failAfter
    lock.unlock()
    if fails { throw MigrationSubmitBoundaryError.offline }
    if count > 1 { try afterFirst?() }
    return store
  }
}
private final class MigrationSubmitRecorder: MigrationExtrinsicSubmitting {
  var accounts = [AccountItem](), purposes = [Sora2PendingSubmissionPurpose](), queues = [String]()
  var signers = [SigningWrapperProtocol](), leaseCount = 0
  var result: Result<String, Error> = .failure(MigrationSubmitBoundaryError.offline)
  var callbackHash: String?, beforeValidation: (() -> Void)?, hold = false
  var pending: ExtrinsicSubmitClosure?
  let builder = MigrationSubmitBuilder()
  func submit(
    _ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
    lifecycleLease: WalletLifecycleLease?, purpose: Sora2PendingSubmissionPurpose,
    preSigningValidation: (() throws -> Void)?, runningIn queue: DispatchQueue,
    completion: @escaping ExtrinsicSubmitClosure
  ) {
    purposes.append(purpose)
    queues.append(queue.label)
    signers.append(signer)
    if lifecycleLease != nil { leaseCount += 1 }
    do {
      beforeValidation?()
      try preSigningValidation?()
      _ = try closure(builder)
      if hold { pending = completion } else { completion(result, callbackHash, nil) }
    } catch { completion(.failure(error), nil, nil) }
  }
  func finish() {
    let callback = pending
    pending = nil
    callback?(result, callbackHash, nil)
  }
}

private final class MigrationSubmitBuilder: SoraPassport.ExtrinsicBuilderProtocol {
  var calls: [JSON] = []
  var atomicSelections: [Bool] = []
  func with<A: Codable>(address: A) throws -> Self {
    XCTFail("Unexpected address binding")
    return self
  }
  func with(nonce: UInt32) -> Self {
    XCTFail("Unexpected nonce")
    return self
  }
  func with(era: Era, blockHash: String) -> Self {
    XCTFail("Unexpected era")
    return self
  }
  func with(tip: BigUInt) -> Self {
    XCTFail("Unexpected tip")
    return self
  }
  func with(shouldUseAtomicBatch: Bool) -> Self {
    atomicSelections.append(shouldUseAtomicBatch)
    return self
  }
  func adding<T: RuntimeCallable>(call: T) throws -> Self {
    let encoded = try JSONEncoder.scaleCompatible().encode(
      SoraPassport.EncodingContainer(value: call))
    calls.append(
      try JSONDecoder.scaleCompatible(snakeCase: false).decode(
        SoraPassport.JsonContainer.self, from: encoded
      ).value)
    return self
  }
  func adding(rawCall: Data) throws -> Self {
    XCTFail("Unexpected raw call")
    throw MigrationSubmitBoundaryError.unexpected
  }
  func signing(
    by signer: (Data) throws -> Data, of type: SoraPassport.CryptoType,
    using encoder: DynamicScaleEncoding,
    metadata: RuntimeMetadata
  ) throws -> Self {
    XCTFail("Unexpected signing")
    throw MigrationSubmitBoundaryError.unexpected
  }
  func buildExtrinsic(metadata: RuntimeMetadata) throws -> Extrinsic {
    XCTFail("Unexpected extrinsic build")
    throw MigrationSubmitBoundaryError.unexpected
  }
  func build(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws -> Data {
    throw MigrationSubmitBoundaryError.unexpected
  }
  func buildSignature(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws
    -> Data
  { throw MigrationSubmitBoundaryError.unexpected }
}

private final class SubmissionBoundaryService: MigrationService {
  var testEngine: JSONRPCEngine?
  var testRuntime: SoraPassport.RuntimeCodingServiceProtocol?
  override var engine: JSONRPCEngine? { testEngine }
  override var runtimeRegistry: SoraPassport.RuntimeCodingServiceProtocol? { testRuntime }
}
private final class SubmissionBoundaryRuntime: SoraPassport.RuntimeCodingServiceProtocol {
  func fetchCoderFactoryOperation(
    with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?
  ) -> BaseOperation<RuntimeCoderFactoryProtocol> {
    XCTFail("SubmissionBoundary must not build or sign an extrinsic")
    return ClosureOperation { throw NSError(domain: "eligibility-fixture", code: 1) }
  }
}
private final class SubmissionBoundaryEvents: EventCenterProtocol {
  var values = [EventProtocol](), mainThreads = [Bool]()
  func notify(with event: EventProtocol) {
    values.append(event)
    mainThreads.append(Thread.isMainThread)
  }
  func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) {
    notify(with: event)
    DispatchQueue.main.async(execute: completionOnMain)
  }
  func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) {}
  func remove(observer: EventVisitorProtocol) {}
}
private final class SubmissionBoundaryURLProtocol: URLProtocol {
  private static let lock = NSLock()
  private static var requests = [[String: Any]](), pending = [SubmissionBoundaryURLProtocol]()
  static var result = false, fail = false, hold = false
  static var methods: [String] {
    lock.lock()
    defer { lock.unlock() }
    return requests.compactMap { $0["method"] as? String }
  }
  static var parameters: [Any] {
    lock.lock()
    defer { lock.unlock() }
    return requests.compactMap { $0["params"] }
  }
  static func reset() {
    lock.lock()
    requests = []
    pending = []
    result = false
    fail = false
    hold = false
    lock.unlock()
  }
  static func release() {
    lock.lock()
    let values = pending
    pending = []
    hold = false
    lock.unlock()
    values.forEach { $0.respond() }
  }
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  private var rpc: [String: Any] = [:]
  override func startLoading() {
    var data = request.httpBody ?? Data()
    if data.isEmpty, let stream = request.httpBodyStream {
      stream.open()
      defer { stream.close() }
      var buffer = [UInt8](repeating: 0, count: 4096)
      while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        data.append(buffer, count: count)
      }
    }
    rpc = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    Self.lock.lock()
    Self.requests.append(rpc)
    let held = Self.hold
    if held { Self.pending.append(self) }
    Self.lock.unlock()
    if !held { respond() }
  }
  private func respond() {
    let object: [String: Any] =
      Self.fail
      ? [
        "jsonrpc": "2.0", "id": rpc["id"] ?? 1,
        "error": ["code": -32000, "message": "fixture offline"],
      ]
      : ["jsonrpc": "2.0", "id": rpc["id"] ?? 1, "result": Self.result]
    let data = try! JSONSerialization.data(withJSONObject: object)
    client?.urlProtocol(
      self,
      didReceive: HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}
