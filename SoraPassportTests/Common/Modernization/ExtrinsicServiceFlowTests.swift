// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFModels
import SSFUtils
import XCTest
@testable import SoraPassport

@MainActor
final class ExtrinsicServiceFlowTests: XCTestCase {
    private var fixtures = [ServiceFlowFixture]()
    override func tearDown() { fixtures.forEach { $0.cleanup() }; fixtures = []; super.tearDown() }
    private func make() throws -> ServiceFlowFixture { let f = try ServiceFlowFixture(); fixtures.append(f); return f }
    private func equal<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { XCTAssertEqual(a, b, file: file, line: line) }
    private func rejected(_ body: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async { do { try await body(); XCTFail("Invalid operation succeeded", file: file, line: line) } catch {} }
    func testHexIntegerInitializerRejectsMalformedInputInsteadOfTrapping() {
        for text in ["", "0x", "not-hex", "0xgg", "-1", "1.2", " 12 "] { XCTAssertNil(BigUInt(hexString: text, radix: 16), text) }
    }
    func testHexIntegerInitializerRejectsUnsupportedRadicesInsteadOfTrapping() {
        for radix in [-1, 0, 1, 37, Int.max] { XCTAssertNil(BigUInt(hexString: "1", radix: radix)) }
    }
    func testHexIntegerInitializerPreservesZeroAndUnprefixedNumbers() {
        equal(BigUInt(hexString: "0x0", radix: 16), 0); equal(BigUInt(hexString: "ff", radix: 16), 255)
        equal(BigUInt(hexString: "0xAB", radix: 16), 171); equal(BigUInt(hexString: "42", radix: 10), 42)
    }
    func testHexIntegerInitializerKeepsValuesBeyondMachineIntegerPrecision() {
        equal(BigUInt(hexString: "0xffffffffffffffffffffffffffffffff", radix: 16), BigUInt(2).power(128) - 1)
    }
    func testRuntimeUpgradeRefreshIsDispatchedToMainWithoutDiscardingValidCache() async throws {
        let live = try JSONDecoder().decode(SSFModels.RuntimeVersion.self, from: Data(#"{"specVersion":134,"transactionVersion":131}"#.utf8))
        let done = expectation(description: "main-thread runtime refresh")
        DispatchQueue.global().async {
            Sora2LiveRuntimeValidator.requestRuntimeRefresh(after: ExtrinsicServiceError.runtimeUpgradeInProgress(spec: 134, transaction: 131), live: live) { version, replacing in
                XCTAssertTrue(Thread.isMainThread); XCTAssertEqual(version.specVersion, 134); XCTAssertFalse(replacing); done.fulfill()
            }
        }
        await fulfillment(of: [done], timeout: 3)
    }
    func testMetadataMismatchRefreshReplacesTheInvalidCachedMetadata() async throws {
        let live = try JSONDecoder().decode(SSFModels.RuntimeVersion.self, from: Data(#"{"specVersion":133,"transactionVersion":131}"#.utf8))
        let done = expectation(description: "replacement refresh")
        Sora2LiveRuntimeValidator.requestRuntimeRefresh(after: ExtrinsicServiceError.unsupportedRuntimeMetadata, live: live) { version, replacing in
            XCTAssertTrue(Thread.isMainThread); XCTAssertEqual(version.specVersion, 133); XCTAssertTrue(replacing); done.fulfill()
        }
        await fulfillment(of: [done], timeout: 3)
    }
    func testUnrelatedErrorsAndAbsentVersionDoNotRefreshRuntime() async throws {
        let live = try JSONDecoder().decode(SSFModels.RuntimeVersion.self, from: Data(#"{"specVersion":133,"transactionVersion":131}"#.utf8))
        var calls = 0
        Sora2LiveRuntimeValidator.requestRuntimeRefresh(after: ServiceFlowFailure.offline, live: live) { _, _ in calls += 1 }
        Sora2LiveRuntimeValidator.requestRuntimeRefresh(after: ExtrinsicServiceError.invalidLocalHash, live: live) { _, _ in calls += 1 }
        Sora2LiveRuntimeValidator.requestRuntimeRefresh(after: ExtrinsicServiceError.unsupportedRuntimeMetadata, live: nil) { _, _ in calls += 1 }
        await Task.yield(); equal(calls, 0)
    }
    func testFeeEstimateEncodesTheRealTransferWithoutUsingAccountKeys() async throws {
        let f = try make(); equal(try await f.fee(), "7"); equal(f.signer.calls, 0)
        equal(f.server.requests(SoraPassport.RPCMethod.feeDetails).count, 1)
        equal(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).count, 0); equal(try f.store.all().count, 0)
        let bytes = try Data(hexStringSSF: XCTUnwrap(f.server.requests(SoraPassport.RPCMethod.feeDetails).first?.first as? String))
        XCTAssertGreaterThan(bytes.count, 100)
    }
    func testPrepareReturnsExactHashCallAndRecoveryWitnessWithoutTransport() async throws {
        let f = try make(); let prepared = try await f.prepare()
        let payload = try prepared.consumeForTransport(); let hex = try payload.hexForFeeQualification(); defer { payload.discard() }
        equal(prepared.hash, try Data(hexStringSSF: hex).blake2b32().toHex(includePrefix: true))
        let call = try XCTUnwrap(prepared.call).map(to: RuntimeCall<SoraTransferCall>.self)
        equal(call.args.amount, 1234567890123456789); equal(call.args.receiver, Data(repeating: 4, count: 32))
        equal(prepared.recoveryContext?.walletId, f.account.address); equal(f.signer.calls, 1)
        XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).isEmpty); equal(try f.store.all().count, 0)
    }
    func testExactFeeQualificationReturnsTheSameSignedBytesThatWereQueried() async throws {
        let f = try make(); let result = try await f.qualify(); equal(result.rawFee, "7")
        let payload = try result.prepared.consumeForTransport(); defer { payload.discard() }
        equal(try payload.hexForFeeQualification(), f.server.requests(SoraPassport.RPCMethod.feeDetails).first?.first as? String)
        equal(f.signer.calls, 1)
    }
    func testMissingWalletSnapshotStopsBeforeSigningOrFeeQuery() async throws {
        let f = try make(); f.snapshot = nil
        await rejected { _ = try await f.prepare() }; equal(f.signer.calls, 0); XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.feeDetails).isEmpty)
    }
    func testSnapshotReadFailureDoesNotUseAnUnverifiedAccount() async throws {
        let f = try make(); f.snapshotFailure = ServiceFlowFailure.offline
        await rejected { _ = try await f.prepare() }; equal(f.signer.calls, 0)
    }
    func testMismatchedNetworkPublicKeyCannotSign() async throws {
        let f = try make(); f.setAccounts([NetworkAccount(walletId: f.account.address, networkId: .sora2, derivationVersion: 1, publicKey: Data(repeating: 8, count: 32), address: f.account.address)])
        await rejected { _ = try await f.prepare() }; equal(f.signer.calls, 0)
    }
    func testDuplicateSoraNetworkRowsCannotSign() async throws {
        let f = try make(); let account = try XCTUnwrap(f.snapshot?.accounts.first); f.setAccounts([account, account])
        await rejected { _ = try await f.prepare() }; equal(f.signer.calls, 0)
    }
    func testDifferentNetworkRowCannotAuthorizeSoraSigning() async throws {
        let f = try make(); f.setAccounts([NetworkAccount(walletId: f.account.address, networkId: .taira, derivationVersion: 1, publicKey: f.account.publicKeyData, address: f.account.address)])
        await rejected { _ = try await f.prepare() }; equal(f.signer.calls, 0)
    }
    func testWrongConnectedGenesisCannotSign() async throws {
        let f = try make(); f.server.genesis = f.server.block
        await rejected { _ = try await f.prepare() }; equal(f.signer.calls, 0)
    }
    func testLiveVersionAheadOfStoredMetadataStopsBeforeSigning() async throws {
        let f = try make(); f.server.spec = 134
        await rejected { _ = try await f.prepare() }; equal(f.signer.calls, 0); equal(f.refreshes.count, 1); equal(f.refreshes.first??.specVersion, 134)
    }
    func testMalformedHeadHeightStopsBeforeSigning() async throws {
        let f = try make(); f.server.height = "not-hex"
        await rejected { _ = try await f.prepare() }; equal(f.signer.calls, 0)
    }
    func testHeightOutsidePlatformRangeStopsBeforeSigning() async throws {
        let f = try make(); f.server.height = "0xffffffffffffffffffffffffffffffff"
        await rejected { _ = try await f.prepare() }; equal(f.signer.calls, 0)
    }
    func testHeadReadFailureCannotProduceASignedPayload() async throws {
        let f = try make(); f.server.failedMethod = SoraPassport.RPCMethod.getHead
        await rejected { _ = try await f.prepare() }; equal(f.signer.calls, 0)
    }
    func testNonceReadFailureCannotProduceASignedPayload() async throws {
        let f = try make(); f.server.failedMethod = SoraPassport.RPCMethod.getExtrinsicNonce
        await rejected { _ = try await f.prepare() }; equal(f.signer.calls, 0)
    }
    func testPreSigningValidationRunsImmediatelyBeforeTheSigner() async throws {
        let f = try make(); var order = [String](); f.signer.onSign = { order.append("sign") }
        _ = try await f.prepare { order.append("validate") }; equal(order, ["validate", "sign"])
    }
    func testFailedPreSigningValidationNeverCallsTheSigner() async throws {
        let f = try make(); await rejected { _ = try await f.prepare { throw ServiceFlowFailure.offline } }; equal(f.signer.calls, 0)
    }
    func testSignerFailureDoesNotQueryFeesOrPersistAPendingTransaction() async throws {
        let f = try make(); f.signer.failure = ServiceFlowFailure.offline
        await rejected { _ = try await f.qualify() }; equal(f.signer.calls, 1); equal(try f.store.all().count, 0)
        XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.feeDetails).isEmpty)
    }
    func testZeroExactFeeIsRejectedWithoutTransport() async throws {
        let f = try make(); f.server.fee = "0x0"; await rejected { _ = try await f.qualify() }
        XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).isEmpty)
    }
    func testMalformedFeeComponentIsNotConvertedToZero() async throws {
        let f = try make(); f.server.fee = "7"; await rejected { _ = try await f.qualify() }
    }
    func testPreparedTransportRecordsTheExactHashAndReleasesSignedBytes() async throws {
        let f = try make(); let prepared = try await f.prepare(); let hash = try await f.send(prepared)
        equal(hash, prepared.hash); equal(try f.store.all().first?.state, .submittedRetained); equal(f.notifications, 1)
        XCTAssertThrowsError(try prepared.consumeForTransport()); equal(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).count, 1)
    }
    func testFeeIncreaseBeforeTransportPreservesRetrySafety() async throws {
        let f = try make(); let prepared = try await f.prepare(); f.server.fee = "0x8"
        await rejected { _ = try await f.send(prepared) }; XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).isEmpty); equal(try f.store.all().count, 0)
    }
    func testPreTransportFailureDoesNotSubmitOrRetainAPendingRecord() async throws {
        let f = try make(); let prepared = try await f.prepare()
        await rejected { _ = try await f.send(prepared) { throw ServiceFlowFailure.offline } }
        equal(try f.store.all().count, 0); XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).isEmpty)
    }
    func testMissingRecoveryWitnessCannotBeSubmitted() async throws {
        let f = try make(); let bytes = Data([1, 2]); let prepared = PreparedExtrinsicSubmission(data: bytes, hash: try bytes.blake2b32().toHex(includePrefix: true))
        await rejected { _ = try await f.send(prepared) }; equal(f.server.requests(SoraPassport.RPCMethod.feeDetails).count, 0); equal(try f.store.all().count, 0)
    }
    func testMismatchedReturnedHashRetainsAnAmbiguousJournal() async throws {
        let f = try make(); let prepared = try await f.prepare(); f.server.returnedHash = f.server.block
        await rejected { _ = try await f.send(prepared) }; equal(try f.store.all().first?.state, .submissionUnknown)
        equal(try f.store.all().first?.extrinsicHash, prepared.hash.replacingOccurrences(of: "0x", with: ""))
    }
    func testTransportFailureRetainsAnAmbiguousJournalAndNeverRetries() async throws {
        let f = try make(); let prepared = try await f.prepare(); f.server.failedMethod = SoraPassport.RPCMethod.submitExtrinsic
        await rejected { _ = try await f.send(prepared) }; equal(try f.store.all().first?.state, .submissionUnknown)
        equal(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).count, 1)
    }
    func testNonLifecycleSignerIsRejectedWithoutStartingAnyRequests() async throws {
        let f = try make(); let done = expectation(description: "non lifecycle signer rejected")
        f.service.prepare(f.call, signer: try DummySigner(cryptoType: .sr25519), runningIn: .main) { result in
            if case .success = result { XCTFail("Unscoped signer admitted") }; done.fulfill()
        }
        await fulfillment(of: [done], timeout: 3); XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.getExtrinsicNonce).isEmpty)
    }
    func testRecoveryRequiredPreventsSigningAndReleasesLifecycleAdmission() async throws {
        let f = try make(); f.settings.walletMigrationRecoveryRequired = true
        await rejected { _ = try await f.prepare() }; equal(f.signer.calls, 0)
        f.settings.walletMigrationRecoveryRequired = false
        let lease = try XCTUnwrap(f.lifecycle.tryAcquireForMutableWalletAccess()); lease.release()
    }
    func testCancellingExactFeePreparationBeforeQueueStartIssuesNoRequests() async throws {
        let f = try make(); f.queue.isSuspended = true; let done = expectation(description: "cancelled preparation completes")
        let handle = f.service.prepareAndEstimateFee(f.call, signer: f.signer, preSigningValidation: {}, runningIn: .main) { result in
            if case .success = result { XCTFail("Cancelled preparation succeeded") }; done.fulfill()
        }
        handle.cancel(); f.queue.isSuspended = false
        await fulfillment(of: [done], timeout: 5); equal(f.signer.calls, 0)
        XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.getExtrinsicNonce).isEmpty)
        let lease = try XCTUnwrap(f.lifecycle.tryAcquireForMutableWalletAccess()); lease.release()
    }
    func testCancellingPreparedTransportBeforeQueueStartRemovesStagedIntent() async throws {
        let f = try make(); let prepared = try await f.prepare(); f.queue.isSuspended = true
        let done = expectation(description: "cancelled transport completes")
        let handle = f.service.submitPrepared(prepared, retainingTransportWitness: true, expectedRawFee: "7", preTransportValidation: {}, runningIn: .main) { result in
            if case .success = result { XCTFail("Cancelled transport succeeded") }; done.fulfill()
        }
        equal(try f.store.all().count, 1); handle.cancel(); f.queue.isSuspended = false
        await fulfillment(of: [done], timeout: 5); equal(try f.store.all().count, 0)
        XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).isEmpty)
        let lease = try XCTUnwrap(f.lifecycle.tryAcquireForMutableWalletAccess()); lease.release()
    }
    func testCancelledPreparedPayloadCannotBeReused() async throws {
        let f = try make(); let prepared = try await f.prepare(); prepared.discard()
        await rejected { _ = try await f.send(prepared) }; equal(try f.store.all().count, 0)
        XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.feeDetails).isEmpty)
    }
    func testBusyWalletLifecycleRefusesTransportBeforeConsumingThePayload() async throws {
        let f = try make(); let prepared = try await f.prepare(); let lease = try XCTUnwrap(f.lifecycle.tryAcquireForMutableWalletAccess())
        await rejected { _ = try await f.send(prepared) }; lease.release()
        equal(try f.store.all().count, 0); XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).isEmpty)
        let payload = try prepared.consumeForTransport(); payload.discard()
    }
    func testRecoveryBecomingRequiredBeforeTransportCannotSubmit() async throws {
        let f = try make(); let prepared = try await f.prepare(); f.settings.walletMigrationRecoveryRequired = true
        await rejected { _ = try await f.send(prepared) }; equal(try f.store.all().count, 0)
        XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).isEmpty)
    }
    func testSecondPreTransportCheckCanRejectAfterTheFeeRead() async throws {
        let f = try make(); let prepared = try await f.prepare(); var checks = 0
        await rejected { _ = try await f.send(prepared) { checks += 1; if checks == 2 { throw ServiceFlowFailure.offline } } }
        equal(checks, 2); equal(try f.store.all().count, 0); equal(f.server.requests(SoraPassport.RPCMethod.feeDetails).count, 1)
        XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).isEmpty)
    }
    func testLegacySubmitReturnsMatchingHashAndActualCallWithDurableState() async throws {
        let f = try make(); let result = try await f.legacySubmit()
        equal(result.0.replacingOccurrences(of: "0x", with: ""), result.1)
        let call = try XCTUnwrap(result.2?.call).map(to: RuntimeCall<SoraTransferCall>.self)
        equal(call.args.amount, 1234567890123456789); equal(try f.store.all().first?.state, .submitted)
        equal(f.events.submitted, 1); equal(f.notifications, 1); equal(f.signer.calls, 1)
    }
    func testLegacySubmitRefusesAnUnscopedSignerBeforeAnyRPC() async throws {
        let f = try make(); await rejected { _ = try await f.legacySubmit(signer: DummySigner(cryptoType: .sr25519)) }
        equal(f.signer.calls, 0); XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.getExtrinsicNonce).isEmpty)
    }
    func testLegacySubmitRetainsUnknownStateWhenTheReturnedHashDiffers() async throws {
        let f = try make(); f.server.returnedHash = f.server.block
        await rejected { _ = try await f.legacySubmit() }; equal(try f.store.all().first?.state, .submissionUnknown)
        equal(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).count, 1)
    }
    func testLegacyTransportFailureRetainsRecoveryWitnessAndDoesNotRetry() async throws {
        let f = try make(); f.server.failedMethod = SoraPassport.RPCMethod.submitExtrinsic
        await rejected { _ = try await f.legacySubmit() }; equal(try f.store.all().first?.state, .submissionUnknown)
        XCTAssertNotNil(try f.store.all().first?.recoveryContext); equal(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).count, 1)
    }
    func testLegacySigningFailureNeverStagesOrAnnouncesASubmission() async throws {
        let f = try make(); f.signer.failure = ServiceFlowFailure.offline
        await rejected { _ = try await f.legacySubmit() }; equal(try f.store.all().count, 0); equal(f.events.submitted, 0)
        XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).isEmpty)
    }
    func testLegacyPreSigningValidationRunsBeforeSecretUse() async throws {
        let f = try make(); await rejected { _ = try await f.legacySubmit(validate: { throw ServiceFlowFailure.offline }) }
        equal(f.signer.calls, 0); equal(try f.store.all().count, 0); equal(f.events.submitted, 0)
    }
    func testLegacyRecoveryLatchBetweenSigningAndTransportPreventsTheRPC() async throws {
        let f = try make(); f.signer.onSign = { f.settings.walletMigrationRecoveryRequired = true }
        await rejected { _ = try await f.legacySubmit() }; equal(f.signer.calls, 1)
        equal(try f.store.all().count, 0); XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).isEmpty)
    }
    func testLegacyMissingWalletSnapshotDoesNotAnnounceOrTransmit() async throws {
        let f = try make(); f.snapshot = nil
        await rejected { _ = try await f.legacySubmit() }; equal(f.events.submitted, 0); equal(f.signer.calls, 0)
        XCTAssertTrue(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).isEmpty)
    }
    func testDuplicatePreparedTransactionCannotEnterTransportTwice() async throws {
        let f = try make(); let prepared = try await f.prepare(); _ = try await f.send(prepared)
        await rejected { _ = try await f.send(prepared) }; equal(f.server.requests(SoraPassport.RPCMethod.submitExtrinsic).count, 1)
        equal(try f.store.all().count, 1)
    }
}
private enum ServiceFlowFailure: Swift.Error { case offline, unexpected }
@MainActor
private final class ServiceFlowFixture {
    let server = ServiceFlowServer(), settings = InMemorySettingsManager(), queue = OperationQueue(), events = ServiceFlowEvents()
    var lifecycle: WalletLifecycleCoordinator!
    let account: AccountItem, signer: ServiceFlowSigner, store: Sora2PendingSubmissionStore
    let directory: URL, session: URLSession, runtime: ServiceFlowRuntime
    var snapshot: WalletNetworkSnapshot?, snapshotFailure: Swift.Error?, notifications = 0
    var refreshes = [SSFModels.RuntimeVersion?]()
    var service: ExtrinsicService!
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let metadata = try! Data(contentsOf: root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec133.scale"))
    static let coder: Result<RuntimeCoderFactory, Swift.Error> = Result {
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(chainId: PIIndexerClient.soraMainnetGenesis,
            runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(chain: PIIndexerClient.soraMainnetGenesis, version: 133, txVersion: 131, metadata: metadata, resolver: nil),
            ownTypes: Data(contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")), dataHasher: .twox256)
        return RuntimeCoderFactory(catalog: snapshot.typeRegistryCatalog, specVersion: 133, txVersion: 131, metadata: snapshot.metadata)
    }
    init() throws {
        let key = Data(repeating: 3, count: 32)
        account = AccountItem(address: try SS58AddressFactory().addressFromAccountId(data: key, type: SoraPassport.Chain.sora.addressType()), cryptoType: .sr25519, networkType: SoraPassport.Chain.sora.addressType(), username: "Public fixture", publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: false)
        signer = ServiceFlowSigner(account: account)
        snapshot = WalletNetworkSnapshot(schemaVersion: 1, selectedWalletId: account.address, wallets: [.init(id: account.address, displayName: "Fixture", existingSoraAddress: account.address, secretSource: .rawSeed)], accounts: [.init(walletId: account.address, networkId: .sora2, derivationVersion: 1, publicKey: key, address: account.address)], createdAt: Date())
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); store = try Sora2PendingSubmissionStore(baseURL: directory)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ServiceFlowURLProtocol.self]; session = URLSession(configuration: config)
        server.metadata = Self.metadata.toHex(includePrefix: true); ServiceFlowURLProtocol.handler = { [server] in try server.response($0) }
        let engine = Sora2BoundedHTTPJSONRPCEngine(nodeURL: URL(string: "https://extrinsic.test")!, session: session)
        runtime = ServiceFlowRuntime(coder: try Self.coder.get())
        let gate = WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false }, credentialRepairPending: { false })
        lifecycle = WalletLifecycleCoordinator(recoveryGate: gate)
        service = ExtrinsicService(address: account.address, cryptoType: .sr25519, runtimeRegistry: runtime, engine: engine, operationManager: OperationManager(operationQueue: queue), liveRuntimeIdentityCache: .init(), pendingSubmissionStore: store, loadWalletNetworkSnapshot: { [weak self] in if let error = self?.snapshotFailure { throw error }; return self?.snapshot }, lifecycleCoordinator: lifecycle, recoveryGate: gate, onSubmission: { [weak self] in self?.notifications += 1 }, eventCenter: events, refreshRuntime: { [weak self] _, version in self?.refreshes.append(version) })
    }
    var call: ExtrinsicBuilderClosure { { builder in try builder.adding(call: RuntimeCall<SoraTransferCall>.transfer(SoraTransferCall(receiver: Data(repeating: 4, count: 32), amount: 1234567890123456789, assetId: AssetId(wrappedValue: WalletAssetId.xor.rawValue)))) } }
    func fee() async throws -> String { try await withCheckedThrowingContinuation { continuation in service.estimateFee(call, runningIn: .main) { continuation.resume(with: $0) } } }
    func prepare(validate: @escaping () throws -> Void = {}) async throws -> PreparedExtrinsicSubmission {
        try await withCheckedThrowingContinuation { continuation in service.prepare(call, signer: signer, lifecycleLease: nil, runtimeValidation: nil, preSigningValidation: validate, runningIn: .main) { continuation.resume(with: $0) } }
    }
    func qualify() async throws -> PreparedExtrinsicFeeQualification {
        try await withCheckedThrowingContinuation { continuation in _ = service.prepareAndEstimateFee(call, signer: signer, preSigningValidation: {}, runningIn: .main) { continuation.resume(with: $0) } }
    }
    func send(_ prepared: PreparedExtrinsicSubmission, validate: @escaping () throws -> Void = {}) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in _ = service.submitPrepared(prepared, retainingTransportWitness: true, expectedRawFee: "7", preTransportValidation: validate, runningIn: .main) { continuation.resume(with: $0) } }
    }
    func legacySubmit(signer alternateSigner: SigningWrapperProtocol? = nil, validate: (() throws -> Void)? = nil) async throws -> (String, String?, Extrinsic?) {
        try await withCheckedThrowingContinuation { continuation in
            service.submit(call, signer: alternateSigner ?? signer, lifecycleLease: nil, purpose: .generic, preSigningValidation: validate, runningIn: .main) { result, hash, extrinsic in
                continuation.resume(with: result.map { ($0, hash, extrinsic) })
            }
        }
    }
    func setAccounts(_ accounts: [NetworkAccount]) { let old = snapshot!; snapshot = .init(schemaVersion: old.schemaVersion, selectedWalletId: old.selectedWalletId, wallets: old.wallets, accounts: accounts, createdAt: old.createdAt) }
    func cleanup() { signer.onSign = nil; queue.isSuspended = false; queue.cancelAllOperations(); session.invalidateAndCancel(); ServiceFlowURLProtocol.handler = nil; try? FileManager.default.removeItem(at: directory) }
}
private final class ServiceFlowSigner: LifecycleSigningWrapperProtocol {
    let signingAccount: AccountItem; var calls = 0, onSign: (() -> Void)?, failure: Swift.Error?
    init(account: AccountItem) { signingAccount = account }
    func sign(_ originalData: Data) throws -> IRSignatureProtocol { XCTFail("Signing must carry a lifecycle lease"); throw ServiceFlowFailure.unexpected }
    func sign(_ originalData: Data, lifecycleLease: WalletLifecycleLease) throws -> IRSignatureProtocol {
        calls += 1; onSign?(); if let failure { throw failure }; return try DummySigner(cryptoType: .sr25519).sign(originalData)
    }
}
private final class ServiceFlowRuntime: SoraPassport.RuntimeCodingServiceProtocol {
    let coder: RuntimeCoderFactoryProtocol
    init(coder: RuntimeCoderFactoryProtocol) { self.coder = coder }
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> { ClosureOperation { self.coder } }
}
private final class ServiceFlowServer {
    let block = "0x" + String(repeating: "ab", count: 32)
    var genesis = PIIndexerClient.soraMainnetGenesis, metadata = "", height = "0x190", spec = 133, fee = "0x7", returnedHash: String?, failedMethod: String?
    private let lock = NSLock(); private var calls = [(String, [Any])]()
    func requests(_ method: String) -> [[Any]] { lock.lock(); defer { lock.unlock() }; return calls.filter { $0.0 == method }.map { $0.1 } }
    func response(_ request: URLRequest) throws -> Data {
        let body: Data
        if let bytes = request.httpBody { body = bytes }
        else if let stream = request.httpBodyStream { stream.open(); defer { stream.close() }; var bytes = Data(); var buffer = [UInt8](repeating: 0, count: 8192); while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; bytes.append(buffer, count: count) }; body = bytes }
        else { throw ServiceFlowFailure.unexpected }
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any]); let method = try XCTUnwrap(object["method"] as? String); let params = object["params"] as? [Any] ?? []
        lock.lock(); calls.append((method, params)); lock.unlock()
        if failedMethod == method { throw ServiceFlowFailure.offline }
        let result: Any
        switch method {
        case SoraPassport.RPCMethod.getExtrinsicNonce: result = 5
        case SoraPassport.RPCMethod.getBlockHash: result = genesis
        case SoraPassport.RPCMethod.getRuntimeVersion: result = ["specVersion": spec, "transactionVersion": 131]
        case SoraPassport.RPCMethod.getRuntimeMetadata: result = metadata
        case SoraPassport.RPCMethod.getHead: result = block
        case SoraPassport.RPCMethod.getHeader: result = ["number": height, "parentHash": block, "extrinsicsRoot": block, "stateRoot": block, "digest": ["logs": []]]
        case SoraPassport.RPCMethod.feeDetails: result = ["inclusionFee": ["baseFee": fee, "lenFee": "0x0", "adjustedWeightFee": "0x0"]]
        case SoraPassport.RPCMethod.submitExtrinsic:
            result = try returnedHash ?? Data(hexStringSSF: XCTUnwrap(params.first as? String)).blake2b32().toHex(includePrefix: true)
        default: XCTFail("Unexpected RPC \(method)"); throw ServiceFlowFailure.unexpected
        }
        return try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": object["id"]!, "result": result])
    }
}
private final class ServiceFlowURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> Data)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do { let data = try XCTUnwrap(Self.handler)(request); let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!; client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed); client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self) }
        catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private final class ServiceFlowEvents: EventCenterProtocol {
    var submitted = 0
    func notify(with event: EventProtocol) { if event is ExtricsicSubmittedEvent { submitted += 1 } }
    func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) { notify(with: event); DispatchQueue.main.async(execute: completionOnMain) }
    func add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?) {}
    func remove(observer: EventVisitorProtocol) {}
}
