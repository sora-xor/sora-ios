// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import SSFUtils
import XCTest

@testable import SoraPassport

/// Real journal recovery against intercepted PI and finalized-node responses.
/// Each test owns a temporary directory; no signer or live transport is used.
@MainActor
final class PolkamarktPendingRecoveryFlowTests: XCTestCase {
  private var directory: URL!, store: PolkamarktPendingStore!, witness: Sora2PendingSubmissionStore!
  private var session: URLSession!, rpcSession: URLSession!, client: PIIndexerClient!,
    rpc: PolkamarktRPCClient!
  private let server = PendingRecoveryServer()
  private var executionCalls = 0
  private var execution: [String: Bool] = [:]
  private var executionError: Error?
  private var duringExecution: (() async throws -> Void)?
  override func setUp() {
    super.setUp()
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    store = try! PolkamarktPendingStore(baseURL: directory)
    witness = try! Sora2PendingSubmissionStore(baseURL: directory)
    server.reset()
    executionCalls = 0
    execution = [server.hash: true]
    executionError = nil
    duringExecution = nil
    PIStubIndexerProtocol.install { [server] in server.respond($0) }
    session = PIStubIndexerProtocol.session()
    client = PIIndexerClient(
      session: session, historyShapeMemory: PIHistoryShapeMemory(),
      cacheDirectory: directory.appendingPathComponent("cache"), retryPause: { _ in })
    PendingRecoveryRPC.install(server)
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [PendingRecoveryRPC.self]
    rpcSession = URLSession(configuration: config)
    rpc = PolkamarktRPCClient(
      engine: Sora2BoundedHTTPJSONRPCEngine(
        nodeURL: URL(string: "https://recovery.test")!, session: rpcSession))
  }
  override func tearDown() {
    session.invalidateAndCancel()
    rpcSession.invalidateAndCancel()
    PIStubIndexerProtocol.uninstall()
    PendingRecoveryRPC.install(nil)
    duringExecution = nil
    store = nil
    witness = nil
    client = nil
    rpc = nil
    try? FileManager.default.removeItem(at: directory)
    super.tearDown()
  }
  private func equal<T: Equatable>(
    _ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line
  ) { XCTAssertEqual(a, b, file: file, line: line) }
  private func seed(
    _ state: PolkamarktPendingState = .submitted, account: String = "wallet-a", hash: String? = nil
  ) async throws -> PolkamarktPendingMutation {
    let date = Date(timeIntervalSince1970: 1)
    var row = PolkamarktPendingMutation(
      id: UUID(), account: account, action: "buy_yes", marketIds: [42], createdAt: date,
      updatedAt: date, extrinsicHash: nil, state: .preparing, finalizedBlock: nil, errorClass: nil)
    row = try await store.put(row)
    if state == .preparing { return row }
    row.extrinsicHash = hash ?? server.hash
    row.state = .signedBeforeTransport
    row.updatedAt = date.addingTimeInterval(1)
    row = try await store.put(row)
    if state == .signedBeforeTransport { return row }
    row.state = state
    row.updatedAt = date.addingTimeInterval(2)
    if state == .failedBeforeSubmission { row.errorClass = "cancelled" }
    return try await store.put(row)
  }
  private func reconcile(_ account: String = "wallet-a") async throws -> [PolkamarktPendingMutation]
  {
    try await store.reconcileFinalizedHistory(account: account, client: client, rpc: rpc) {
      [self] block, indices in
      equal(block, server.blockHash)
      executionCalls += 1
      if let duringExecution { try await duringExecution() }
      if let executionError { throw executionError }
      return execution.filter { indices[$0.key] != nil }
    }
  }
  private func rejects(file: StaticString = #filePath, line: UInt = #line) async {
    do {
      _ = try await reconcile()
      XCTFail("Unqualified recovery was accepted", file: file, line: line)
    } catch {}
  }
  func testEmptyJournalDoesNotReadIndexerOrNode() async throws {
    equal(try await reconcile(), [])
    equal(server.historyRequests, 0)
    equal(server.rpcMethods, [])
  }
  func testPreparingRecordIsDurablyFailedBeforeSubmission() async throws {
    _ = try await seed(.preparing)
    let rows = try await reconcile()
    equal(rows.first?.state, .failedBeforeSubmission)
    equal(rows.first?.errorClass, "interrupted_before_signed_hash")
    equal(try await store.all(), rows)
    equal(server.historyRequests, 0)
  }
  func testPreparingRecordForAnotherWalletIsNotTouched() async throws {
    let row = try await seed(.preparing, account: "wallet-b")
    equal(try await reconcile(), [row])
    equal(server.historyRequests, 0)
  }
  func testSignedHashWithoutWitnessIsRetrySafe() async throws {
    _ = try await seed(.signedBeforeTransport)
    let rows = try await reconcile()
    equal(rows.first?.state, .failedBeforeSubmission)
    equal(rows.first?.errorClass, "interrupted_before_transport_staging")
    equal(server.historyRequests, 0)
  }
  func testUnadmittedWitnessIsRemovedOnlyAfterFeatureFailurePersists() async throws {
    _ = try await seed(.signedBeforeTransport)
    _ = try witness.stage(account: "wallet-a", hash: server.hash, retainingTransportWitness: true)
    let rows = try await reconcile()
    equal(rows.first?.state, .failedBeforeSubmission)
    equal(rows.first?.errorClass, "interrupted_before_transport_admission")
    equal(try witness.all().count, 0)
    equal(try await store.all(), rows)
  }
  func testAdmittedWitnessRemainsAmbiguousWhenNoHistoryExists() async throws {
    _ = try await seed(.signedBeforeTransport)
    _ = try witness.stage(account: "wallet-a", hash: server.hash)
    server.empty = true
    let rows = try await reconcile()
    equal(rows.first?.state, .submissionUnknown)
    equal(rows.first?.errorClass, "interrupted_after_transport_admission")
    equal(try witness.all().first?.state, .submitting)
  }
  func testUnknownTransportWitnessRemainsAmbiguousWithoutHistory() async throws {
    _ = try await seed(.signedBeforeTransport)
    let w = try witness.stage(account: "wallet-a", hash: server.hash)
    try witness.update(w, state: .submissionUnknown)
    server.empty = true
    equal(try await reconcile().first?.state, .submissionUnknown)
    equal(try witness.all().first?.state, .submissionUnknown)
  }
  func testRetainedSuccessWitnessAdvancesFeatureAndBecomesPrunable() async throws {
    _ = try await seed(.signedBeforeTransport)
    let w = try witness.stage(account: "wallet-a", hash: server.hash)
    try witness.update(w, state: .submittedRetained)
    server.empty = true
    equal(try await reconcile().first?.state, .submitted)
    equal(try witness.all().first?.state, .submitted)
  }
  func testSubmittedWitnessAdvancesSignedFeature() async throws {
    _ = try await seed(.signedBeforeTransport)
    let w = try witness.stage(account: "wallet-a", hash: server.hash)
    try witness.update(w, state: .submitted)
    server.empty = true
    equal(try await reconcile().first?.state, .submitted)
  }
  func testWitnessForDifferentAccountFailsClosed() async throws {
    let row = try await seed(.signedBeforeTransport)
    _ = try witness.stage(account: "wallet-b", hash: server.hash)
    await rejects()
    equal(try await store.all(), [row])
    equal(server.historyRequests, 0)
  }
  func testSubmittedFeatureFinishesRetainedWitnessAcknowledgement() async throws {
    _ = try await seed()
    let w = try witness.stage(account: "wallet-a", hash: server.hash)
    try witness.update(w, state: .submittedRetained)
    server.empty = true
    _ = try await reconcile()
    equal(try witness.all().first?.state, .submitted)
  }
  func testAlreadyFailedFeatureRemovesItsUnadmittedWitness() async throws {
    _ = try await seed(.failedBeforeSubmission)
    _ = try witness.stage(account: "wallet-a", hash: server.hash, retainingTransportWitness: true)
    _ = try await reconcile()
    equal(try witness.all().count, 0)
    equal(server.historyRequests, 0)
  }
  func testCanonicalSuccessFinalizesExactHashAndPersistsHeight() async throws {
    _ = try await seed()
    let rows = try await reconcile()
    equal(rows.first?.state, .finalized)
    equal(rows.first?.finalizedBlock, 900)
    equal(executionCalls, 1)
    equal(try await store.all(), rows)
  }
  func testCanonicalDispatchFailureMarksRejectedInsteadOfSuccessful() async throws {
    _ = try await seed()
    execution[server.hash] = false
    let rows = try await reconcile()
    equal(rows.first?.state, .rejected)
    equal(rows.first?.finalizedBlock, 900)
  }
  func testIndexerSuccessDoesNotOverrideCanonicalDispatchFailure() async throws {
    _ = try await seed()
    execution[server.hash] = false
    equal(try await reconcile().first?.state, .rejected)
  }
  func testCanonicalSuccessAcknowledgesAnUnknownWitness() async throws {
    _ = try await seed(.submissionUnknown)
    let w = try witness.stage(account: "wallet-a", hash: server.hash)
    try witness.update(w, state: .submissionUnknown)
    equal(try await reconcile().first?.state, .finalized)
    equal(try witness.all().first?.state, .submitted)
  }
  func testAbsentExecutionEvidenceKeepsTheTransactionPending() async throws {
    let row = try await seed()
    execution = [:]
    equal(try await reconcile(), [row])
    equal(executionCalls, 1)
  }
  func testAHashNotInTheCanonicalBlockCannotBeFinalized() async throws {
    let row = try await seed()
    server.extrinsics = ["0x0102"]
    equal(try await reconcile(), [row])
  }
  func testMismatchedIndexerBlockHashCannotBeFinalized() async throws {
    let row = try await seed()
    server.indexedBlockHash = String(repeating: "cd", count: 32)
    equal(try await reconcile(), [row])
  }
  func testMissingCanonicalBlockKeepsTheTransactionPending() async throws {
    let row = try await seed()
    server.missingBlock = true
    equal(try await reconcile(), [row])
    equal(executionCalls, 0)
  }
  func testBlockBeyondNodeFinalityKeepsTheTransactionPending() async throws {
    let row = try await seed()
    server.finalized = 899
    equal(try await reconcile(), [row])
    equal(executionCalls, 0)
  }
  func testEmptyLiveHistoryDoesNotInferTransactionFailure() async throws {
    let row = try await seed()
    server.empty = true
    equal(try await reconcile(), [row])
    equal(executionCalls, 0)
  }
  func testIndexerFailureLeavesTheJournalUnchanged() async throws {
    let row = try await seed()
    server.status = 503
    await rejects()
    equal(try await store.all(), [row])
    equal(executionCalls, 0)
  }
  func testExecutionReadFailureLeavesTheJournalUnchanged() async throws {
    let row = try await seed()
    executionError = URLError(.timedOut)
    await rejects()
    equal(try await store.all(), [row])
  }
  func testCancelledExecutionReadLeavesTheJournalUnchanged() async throws {
    let row = try await seed()
    executionError = CancellationError()
    await rejects()
    equal(try await store.all(), [row])
  }
  func testUnrelatedIndexedAccountCannotResolveTheJournal() async throws {
    let row = try await seed()
    server.historyAccount = "wallet-b"
    await rejects()
    equal(try await store.all(), [row])
  }
  func testMissingIndexedBlockHeightCannotResolveTheJournal() async throws {
    let row = try await seed()
    server.omitHeight = true
    await rejects()
    equal(try await store.all(), [row])
  }
  func testMissingIndexedBlockHashCannotResolveTheJournal() async throws {
    let row = try await seed()
    server.omitHash = true
    await rejects()
    equal(try await store.all(), [row])
  }
  func testNewMutationArrivingDuringExecutionReadIsNotErased() async throws {
    _ = try await seed()
    duringExecution = { [self] in _ = try await seed(.preparing, account: "wallet-b") }
    let rows = try await reconcile()
    equal(rows.count, 2)
    equal(rows.first?.state, .finalized)
    equal(rows.last?.account, "wallet-b")
    equal(rows.last?.state, .preparing)
  }
  func testAConcurrentTerminalResultIsNeverRegressed() async throws {
    var row = try await seed()
    duringExecution = { [self] in
      row.state = .rejected
      row.finalizedBlock = 899
      row.updatedAt = Date()
      _ = try await store.put(row)
    }
    let rows = try await reconcile()
    equal(rows.first?.state, .rejected)
    equal(rows.first?.finalizedBlock, 899)
  }
  func testRepeatedRecoveryDoesNotRequeryAlreadyTerminalRows() async throws {
    _ = try await seed()
    let rows = try await reconcile()
    let count = server.historyRequests
    equal(try await reconcile(), rows)
    equal(server.historyRequests, count)
  }
  func testRecoveryCanReleaseAdmissionOnlyAfterDurableTerminalResult() async throws {
    _ = try await seed()
    _ = try await reconcile()
    try await store.requireMutationAdmission(account: "wallet-a")
  }
}

private final class PendingRecoveryServer {
  let hash = "03170a2e7597b7b7e3d84c05391d139a62b157e78786d8c082f29dcf4c111314"
  let blockHash = String(repeating: "ab", count: 32)
  var indexedBlockHash = String(repeating: "ab", count: 32), historyAccount = "wallet-a",
    finalized = 1000, status = 200
  var empty = false, missingBlock = false, omitHeight = false, omitHash = false,
    extrinsics = ["0x00"]
  private let lock = NSLock()
  private var histories = 0
  private var methods = [String]()
  var historyRequests: Int {
    lock.lock()
    defer { lock.unlock() }
    return histories
  }
  var rpcMethods: [String] {
    lock.lock()
    defer { lock.unlock() }
    return methods
  }
  func reset() {
    indexedBlockHash = blockHash
    historyAccount = "wallet-a"
    finalized = 1000
    status = 200
    empty = false
    missingBlock = false
    omitHeight = false
    omitHash = false
    extrinsics = ["0x00"]
    histories = 0
    methods = []
  }
  func respond(_ r: PIStubIndexerProtocol.Request) -> PIStubIndexerProtocol.Response {
    if r.operation == "MobileHealth" {
      return .init(
        body: PIAdvancingIndexer.health(
          indexed: 1000, finalized: 1001, indexedAt: Int(Date().timeIntervalSince1970) - 1))
    }
    lock.lock()
    histories += 1
    lock.unlock()
    guard status == 200, r.operation == "MobileHistory" else {
      return .init(status: status == 200 ? 400 : status, body: "{}")
    }
    var row: [String: Any] = [
      "id": "0x" + hash, "address": historyAccount, "dataFrom": historyAccount,
      "dataTo": "wallet-c", "timestamp": 100, "networkFee": "7", "execution": ["success": true],
    ]
    if !omitHeight { row["blockHeight"] = 900 }
    if !omitHash { row["blockHash"] = "0x" + indexedBlockHash }
    let page: [String: Any] = [
      "nodes": empty ? [] : [row],
      "pageInfo": [
        "hasNextPage": false, "hasPreviousPage": false, "startCursor": "c1", "endCursor": "c1",
      ], "totalCount": empty ? 0 : 1,
    ]
    return .init(
      body: String(
        data: try! JSONSerialization.data(withJSONObject: ["data": ["historyElements": page]]),
        encoding: .utf8)!)
  }
  func rpc(_ method: String) -> Any {
    lock.lock()
    methods.append(method)
    lock.unlock()
    func header(_ height: Int) -> [String: Any] {
      [
        "parentHash": "0x" + blockHash, "number": "0x" + String(height, radix: 16),
        "stateRoot": "0x" + blockHash, "extrinsicsRoot": "0x" + blockHash, "digest": ["logs": []],
      ]
    }
    switch method {
    case SoraPassport.RPCMethod.getHead: return "0x" + blockHash
    case SoraPassport.RPCMethod.getHeader: return header(finalized)
    case SoraPassport.RPCMethod.getBlockHash:
      return missingBlock ? NSNull() : "0x" + blockHash as Any
    case SoraPassport.RPCMethod.getChainBlock:
      return ["block": ["header": header(900), "extrinsics": extrinsics]]
    default: return NSNull()
    }
  }
}
private final class PendingRecoveryRPC: URLProtocol {
  private static let lock = NSLock()
  private static var server: PendingRecoveryServer?
  static func install(_ s: PendingRecoveryServer?) {
    lock.lock()
    server = s
    lock.unlock()
  }
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      var body = request.httpBody ?? Data()
      if body.isEmpty, let stream = request.httpBodyStream {
        stream.open()
        defer { stream.close() }
        var b = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
          let n = stream.read(&b, maxLength: b.count)
          if n <= 0 { break }
          body.append(b, count: n)
        }
      }
      let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
      Self.lock.lock()
      let s = Self.server
      Self.lock.unlock()
      let server = try XCTUnwrap(s)
      let method = try XCTUnwrap(object["method"] as? String)
      let data = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": object["id"] ?? 1, "result": server.rpc(method),
      ])
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil,
        headerFields: ["Content-Type": "application/json"])!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch { client?.urlProtocol(self, didFailWithError: error) }
  }
  override func stopLoading() {}
}
