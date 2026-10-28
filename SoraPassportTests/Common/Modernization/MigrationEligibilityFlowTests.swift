import Foundation
import IrohaCrypto
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFUtils
import XCTest
@testable import SoraPassport

/// Eligibility only: real Iroha identity derivation from public fixture entropy,
/// isolated pending journal, and intercept-all HTTP. No signing or submission.
@MainActor
final class MigrationEligibilityFlowTests: XCTestCase {
    private var previous: AccountItem?
    private var directory: URL!
    private var session: URLSession!
    private var service: EligibilityService!
    private var events: EligibilityEvents!
    private var settings: InMemorySettingsManager!
    private var keys: InMemoryKeychain!
    private var account: AccountItem!
    override func setUpWithError() throws {
        previous = SelectedWalletSettings.shared.currentAccount
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EligibilityURLProtocol.self]
        session = URLSession(configuration: configuration)
        EligibilityURLProtocol.reset()
        let key = Data(repeating: 0x44, count: 32)
        let address = try SS58AddressFactory().addressFromAccountId(data: key, type: ApplicationConfig.shared.addressType)
        account = AccountItem(address: address, cryptoType: .sr25519, networkType: 69, username: "Public fixture",
                              publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        SelectedWalletSettings.shared.commitInternalValue(account)
        keys = InMemoryKeychain(); try keys.saveEntropy(Data(repeating: 0, count: 16), address: address)
        settings = InMemorySettingsManager(); events = EligibilityEvents()
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        service = EligibilityService(eventCenter: events, keystore: keys, settings: settings,
                                     operationManager: OperationManager(), logger: Logger.shared, pendingStore: { store })
        service.testEngine = Sora2BoundedHTTPJSONRPCEngine(nodeURL: URL(string: "https://migration-fixture.test")!, session: session)
        service.testRuntime = EligibilityRuntime()
    }
    override func tearDownWithError() throws {
        service = nil; session.invalidateAndCancel(); session = nil
        EligibilityURLProtocol.reset()
        SelectedWalletSettings.shared.commitInternalValue(previous)
        try? FileManager.default.removeItem(at: directory)
        directory = nil; keys = nil; settings = nil; events = nil
    }
    private func settle(_ predicate: @escaping () -> Bool = { false }) async {
        for _ in 0..<100 { if predicate() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
    }
    private func request() async -> Result<String, Swift.Error>? {
        var value: Result<String, Swift.Error>?
        service.requestMigration { value = $0 }
        await settle { value != nil }
        return value
    }
    func testEligibilityTruePublishesMigrationOfferWithoutSigning() async {
        EligibilityURLProtocol.result = true
        service.checkMigration(); await settle { !self.events.values.isEmpty }
        XCTAssertEqual(events.values.count, 1); XCTAssertTrue(events.values.first is MigrationEvent)
        XCTAssertFalse(settings.hasMigrated); XCTAssertTrue(events.mainThreads.allSatisfy { $0 })
        XCTAssertEqual(EligibilityURLProtocol.methods, [SoraPassport.RPCMethod.needsMigration])
    }
    func testEligibilityFalseRecordsThisAccountAndPublishesSuccess() async throws {
        EligibilityURLProtocol.result = false
        service.checkMigration(); await settle { !self.events.values.isEmpty }
        XCTAssertTrue(events.values.first is MigrationSuccsessEvent)
        XCTAssertTrue(settings.hasMigrated)
        XCTAssertTrue(try MigrationAccountCompletionStore.contains(accountAddress: account.address, settings: settings))
    }
    func testLegacyCompletionFlagDoesNotSkipFreshEligibility() async {
        settings.hasMigrated = true; EligibilityURLProtocol.result = true
        service.checkMigration(); await settle { !self.events.values.isEmpty }
        XCTAssertTrue(events.values.first is MigrationEvent)
        XCTAssertEqual(EligibilityURLProtocol.methods.count, 1)
    }
    func testRepeatedCheckWhilePendingUsesOneRequest() async {
        EligibilityURLProtocol.hold = true
        service.checkMigration(); service.checkMigration()
        await settle { !EligibilityURLProtocol.methods.isEmpty }
        XCTAssertEqual(EligibilityURLProtocol.methods.count, 1)
        EligibilityURLProtocol.release(); await settle { !self.events.values.isEmpty }
        XCTAssertEqual(events.values.count, 1)
    }
    func testEligibilityReplyForAChangedWalletCannotPublish() async {
        EligibilityURLProtocol.hold = true
        service.checkMigration(); await settle { !EligibilityURLProtocol.methods.isEmpty }
        SelectedWalletSettings.shared.commitInternalValue(nil)
        EligibilityURLProtocol.release(); try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertTrue(events.values.isEmpty); XCTAssertFalse(settings.hasMigrated)
    }
    func testInvalidatingARequestMakesItsOldReplyInert() async {
        EligibilityURLProtocol.hold = true
        service.checkMigration(); await settle { !EligibilityURLProtocol.methods.isEmpty }
        service.testEngine = nil; service.checkMigration()
        EligibilityURLProtocol.release(); try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertTrue(events.values.isEmpty)
    }
    func testMissingSelectedWalletDoesNotReadNetwork() {
        SelectedWalletSettings.shared.commitInternalValue(nil); service.checkMigration()
        XCTAssertTrue(EligibilityURLProtocol.methods.isEmpty); XCTAssertTrue(events.values.isEmpty)
    }
    func testMissingConnectionDoesNotPublishMigration() {
        service.testEngine = nil; service.checkMigration()
        XCTAssertTrue(EligibilityURLProtocol.methods.isEmpty); XCTAssertTrue(events.values.isEmpty)
    }
    func testCorruptEntropyCannotInventAnIrohaIdentity() throws {
        try keys.updateKey(Data([1]), with: KeystoreTag.entropyTagForAddress(account.address))
        service.checkMigration(); XCTAssertTrue(EligibilityURLProtocol.methods.isEmpty); XCTAssertTrue(events.values.isEmpty)
    }
    func testNonSoraWalletCannotBeOfferedLegacyMigration() async {
        let other = AccountItem(address: account.address, cryptoType: account.cryptoType, networkType: 0, username: account.username, publicKeyData: account.publicKeyData, settings: account.settings, order: account.order, isSelected: true)
        SelectedWalletSettings.shared.commitInternalValue(other)
        service.checkMigration(); try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertTrue(EligibilityURLProtocol.methods.isEmpty); XCTAssertTrue(events.values.isEmpty)
    }
    func testRPCFailureCannotMarkMigrationComplete() async {
        EligibilityURLProtocol.fail = true
        service.checkMigration(); await settle { !EligibilityURLProtocol.methods.isEmpty }
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertTrue(events.values.isEmpty); XCTAssertFalse(settings.hasMigrated)
    }
    func testFailedEligibilityCanBeRetried() async {
        EligibilityURLProtocol.fail = true
        service.checkMigration(); await settle { !EligibilityURLProtocol.methods.isEmpty }
        try? await Task.sleep(nanoseconds: 80_000_000)
        EligibilityURLProtocol.fail = false
        service.checkMigration(); await settle { !self.events.values.isEmpty }
        XCTAssertEqual(EligibilityURLProtocol.methods.count, 2); XCTAssertEqual(events.values.count, 1)
    }
    func testRequestWithNoWalletCompletesWithFailure() async {
        SelectedWalletSettings.shared.commitInternalValue(nil)
        guard case .failure? = await request() else { return XCTFail("Missing account must complete") }
        XCTAssertTrue(EligibilityURLProtocol.methods.isEmpty)
    }
    func testRequestWithNoEngineCompletesWithFailure() async {
        service.testEngine = nil
        guard case .failure? = await request() else { return XCTFail("Missing engine must complete") }
        XCTAssertTrue(EligibilityURLProtocol.methods.isEmpty)
    }
    func testRequestWithNoRuntimeCompletesBeforeRPC() async {
        service.testRuntime = nil
        guard case .failure? = await request() else { return XCTFail("Missing runtime must complete") }
        XCTAssertTrue(EligibilityURLProtocol.methods.isEmpty)
    }
    func testRequestWithCorruptEntropyCompletesBeforeRPC() async throws {
        try keys.updateKey(Data([1]), with: KeystoreTag.entropyTagForAddress(account.address))
        guard case .failure? = await request() else { return XCTFail("Corrupt phrase must complete") }
        XCTAssertTrue(EligibilityURLProtocol.methods.isEmpty)
    }
    func testRequestForNonSoraWalletFailsBeforeRPC() async {
        let other = AccountItem(address: account.address, cryptoType: account.cryptoType, networkType: 0, username: account.username, publicKeyData: account.publicKeyData, settings: account.settings, order: account.order, isSelected: true)
        SelectedWalletSettings.shared.commitInternalValue(other)
        EligibilityURLProtocol.result = false
        guard case .failure? = await request() else { return XCTFail("Wrong network must fail") }
        XCTAssertTrue(EligibilityURLProtocol.methods.isEmpty)
    }
    func testRequestAlreadyMigratedReturnsSuccessWithoutSubmitting() async throws {
        EligibilityURLProtocol.result = false
        guard case .success(let hash)? = await request() else { return XCTFail("Already migrated should succeed") }
        XCTAssertEqual(hash, ""); XCTAssertTrue(settings.hasMigrated)
        XCTAssertTrue(events.values.first is MigrationSuccsessEvent)
        XCTAssertEqual(EligibilityURLProtocol.methods, [SoraPassport.RPCMethod.needsMigration])
    }
    func testRequestEligibilityFailureReturnsFailure() async {
        EligibilityURLProtocol.fail = true
        guard case .failure? = await request() else { return XCTFail("RPC failure must complete") }
        XCTAssertFalse(settings.hasMigrated); XCTAssertTrue(events.values.isEmpty)
    }
    func testRequestCompletesFailureIfWalletChangesDuringEligibility() async {
        EligibilityURLProtocol.hold = true
        var result: Result<String, Swift.Error>?
        service.requestMigration { result = $0 }
        await settle { !EligibilityURLProtocol.methods.isEmpty }
        SelectedWalletSettings.shared.commitInternalValue(nil)
        EligibilityURLProtocol.release(); await settle { result != nil }
        guard case .failure? = result else { return XCTFail("Changed selection must fail") }
        XCTAssertFalse(settings.hasMigrated)
    }
    func testConcurrentRequestFailsPromptlyWithoutAnotherRPC() async {
        EligibilityURLProtocol.hold = true
        service.checkMigration(); await settle { !EligibilityURLProtocol.methods.isEmpty }
        guard case .failure? = await request() else { return XCTFail("A pending check owns eligibility") }
        XCTAssertEqual(EligibilityURLProtocol.methods.count, 1)
        EligibilityURLProtocol.release()
    }
    func testEligibilityUsesScopedFixtureEntropyWithoutMutatingKeys() async throws {
        let identifiers = try keys.allKeyIdentifiers()
        let before = try Dictionary(uniqueKeysWithValues: identifiers.map { ($0, try keys.fetchKey(for: $0)) })
        service.checkMigration(); await settle { !self.events.values.isEmpty }
        XCTAssertEqual(try keys.allKeyIdentifiers().sorted(), identifiers.sorted())
        for (key, data) in before { XCTAssertEqual(try keys.fetchKey(for: key), data) }
        let params = try XCTUnwrap(EligibilityURLProtocol.parameters.first as? [String])
        XCTAssertEqual(params.count, 1); XCTAssertTrue(params[0].hasPrefix("did_sora_")); XCTAssertTrue(params[0].hasSuffix("@sora"))
    }
}
private final class EligibilityService: MigrationService {
    var testEngine: JSONRPCEngine?
    var testRuntime: SoraPassport.RuntimeCodingServiceProtocol?
    override var engine: JSONRPCEngine? { testEngine }
    override var runtimeRegistry: SoraPassport.RuntimeCodingServiceProtocol? { testRuntime }
}
private final class EligibilityRuntime: SoraPassport.RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        XCTFail("Eligibility must not build or sign an extrinsic")
        return ClosureOperation { throw NSError(domain: "eligibility-fixture", code: 1) }
    }
}
private final class EligibilityEvents: EventCenterProtocol {
    var values = [EventProtocol](), mainThreads = [Bool]()
    func notify(with event: EventProtocol) { values.append(event); mainThreads.append(Thread.isMainThread) }
    func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) { notify(with: event); DispatchQueue.main.async(execute: completionOnMain) }
    func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) {}
    func remove(observer: EventVisitorProtocol) {}
}
private final class EligibilityURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var requests = [[String: Any]](), pending = [EligibilityURLProtocol]()
    static var result = false, fail = false, hold = false
    static var methods: [String] { lock.lock(); defer { lock.unlock() }; return requests.compactMap { $0["method"] as? String } }
    static var parameters: [Any] { lock.lock(); defer { lock.unlock() }; return requests.compactMap { $0["params"] } }
    static func reset() { lock.lock(); requests = []; pending = []; result = false; fail = false; hold = false; lock.unlock() }
    static func release() { lock.lock(); let values = pending; pending = []; hold = false; lock.unlock(); values.forEach { $0.respond() } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    private var rpc: [String: Any] = [:]
    override func startLoading() {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(buffer, count: count) }
        }
        rpc = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        Self.lock.lock(); Self.requests.append(rpc)
        let held = Self.hold; if held { Self.pending.append(self) }; Self.lock.unlock()
        if !held { respond() }
    }
    private func respond() {
        let object: [String: Any] = Self.fail
            ? ["jsonrpc": "2.0", "id": rpc["id"] ?? 1, "error": ["code": -32000, "message": "fixture offline"]]
            : ["jsonrpc": "2.0", "id": rpc["id"] ?? 1, "result": Self.result]
        let data = try! JSONSerialization.data(withJSONObject: object)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
