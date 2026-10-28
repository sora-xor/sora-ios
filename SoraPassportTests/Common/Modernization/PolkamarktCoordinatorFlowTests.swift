// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFModels
import SSFUtils
import XCTest
@testable import SoraPassport

@MainActor
final class PolkamarktCoordinatorFlowTests: XCTestCase {
    private var fixtures = [CoordinatorFixture]()
    override func tearDown() { fixtures.forEach { $0.cleanup() }; fixtures = []; super.tearDown() }
    private func make() throws -> CoordinatorFixture { let f = try CoordinatorFixture(); fixtures.append(f); return f }
    private func equal<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { XCTAssertEqual(a, b, file: file, line: line) }
    private func failure(_ expected: PolkamarktRuntimeError? = nil, _ block: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await block(); XCTFail("Invalid coordinator state was accepted", file: file, line: line) }
        catch {
            if let expected { equal(String(describing: error), String(describing: expected), file: file, line: line) }
        }
    }

    func testStatusAcceptsTheSCALEEmptyTupleForEachUnitVariant() throws {
        for status in [PolkamarktMarketStatus.open, .locked, .resolved, .cancelled] {
            let bytes = try JSONSerialization.data(withJSONObject: [status.rawValue, []])
            equal(try JSONDecoder().decode(PolkamarktMarketStatus.self, from: bytes), status)
        }
    }
    func testOutcomeAcceptsTheSCALEEmptyTupleForEachUnitVariant() throws {
        for outcome in PolkamarktOutcome.allCases {
            let bytes = try JSONSerialization.data(withJSONObject: [outcome.rawValue, []])
            equal(try JSONDecoder().decode(PolkamarktOutcome.self, from: bytes), outcome)
        }
    }
    func testStatusAcceptsTheSCALEEmptyCompositeForEachUnitVariant() throws {
        for status in [PolkamarktMarketStatus.open, .locked, .resolved, .cancelled] {
            let bytes = try JSONSerialization.data(withJSONObject: [status.rawValue, [String: Any]()])
            equal(try JSONDecoder().decode(PolkamarktMarketStatus.self, from: bytes), status)
        }
    }
    func testOutcomeAcceptsTheSCALEEmptyCompositeForEachUnitVariant() throws {
        for outcome in PolkamarktOutcome.allCases {
            let bytes = try JSONSerialization.data(withJSONObject: [outcome.rawValue, [String: Any]()])
            equal(try JSONDecoder().decode(PolkamarktOutcome.self, from: bytes), outcome)
        }
    }
    func testStatusRejectsNonemptyOrTrailingSCALEAssociatedValues() throws {
        for value: [Any] in [["Open", [1]], ["Open", [], 1], ["Open", ["unexpected": 1]], ["Open"]] {
            let bytes = try JSONSerialization.data(withJSONObject: value)
            XCTAssertThrowsError(try JSONDecoder().decode(PolkamarktMarketStatus.self, from: bytes))
        }
    }
    func testOutcomeRejectsNonemptyOrTrailingSCALEAssociatedValues() throws {
        for value: [Any] in [["Yes", [1]], ["Yes", [], 1], ["Yes", ["unexpected": 1]], ["Yes"]] {
            let bytes = try JSONSerialization.data(withJSONObject: value)
            XCTAssertThrowsError(try JSONDecoder().decode(PolkamarktOutcome.self, from: bytes))
        }
    }
    func testBuyQuoteBindsTheFinalizedMarketAmountsBalancesAndFeeCall() async throws {
        let f = try make(); let q = try await f.quote()
        equal(q.finalizedBlockHash, f.server.block); equal(q.marketStatus, .open); equal(q.closeBlock, 500)
        equal(q.input, 1000); equal(q.output, 2222); equal(q.marketFee, 5); equal(q.networkFee, 7)
        equal(q.minimumOutput, 2199); equal(q.inputBalance, 10000); equal(q.xorBalance, 20000)
        let call = try XCTUnwrap(f.extrinsics.builders.first?.calls.first).plainMap(to: RuntimeCall<PolkamarktBuyCall>.self)
        equal(call.args.marketId, 42); equal(call.args.collateralIn, 1000); equal(call.args.minSharesOut, 2199)
        equal(f.extrinsics.prepareCount, 0); equal(f.extrinsics.submitCount, 0)
    }
    func testSellQuoteUsesOnlyTheSelectedOutcomeSharesAndExactMinimum() async throws {
        let f = try make(); let q = try await f.quote(side: .sell, outcome: .no)
        equal(q.inputBalance, 1500); equal(q.output, 555); equal(q.minimumOutput, 549); equal(q.marketFee, 1)
        let call = try XCTUnwrap(f.extrinsics.builders.first?.calls.first).plainMap(to: RuntimeCall<PolkamarktSellCall>.self)
        equal(call.args.outcome, .no); equal(call.args.sharesIn, 1000); equal(call.args.minCollateralOut, 549)
    }
    func testRuntimeValidatorAcceptsOnlyThePinnedMetadataIdentity() async throws {
        let f = try make(); let validator = PolkamarktRuntimeValidator(runtimeService: f.runtime, rpc: PolkamarktRPCClient(engine: f.engine))
        let actual = try await validator.validate(); equal(actual.specVersion, 130)
        equal(try PolkamarktRuntimeContract.signingMetadataSHA256(for: actual), PolkamarktRuntimeContract.metadataFileSHA256)
    }
    func testWrongGenesisIsRejectedBeforeMetadataOrFees() async throws {
        let f = try make(); f.server.genesis = f.server.block
        await failure { _ = try await f.quote() }; equal(f.extrinsics.estimateCount, 0)
    }
    func testWrongWireMetadataIsRejectedEvenWithPinnedFactory() async throws {
        let f = try make(); f.server.metadataHex = "0x0000"
        await failure { _ = try await f.quote() }; equal(f.extrinsics.estimateCount, 0)
    }
    func testRuntimeProviderFailureIsNotReplacedWithCachedMarketData() async throws {
        let f = try make(); f.runtime.failure = CoordinatorFailure.offline
        await failure { _ = try await f.quote() }; equal(f.extrinsics.estimateCount, 0)
    }
    func testDisabledFeatureDoesNotReadRuntimeOrBalances() async throws {
        let f = try make(); f.settings.polkamarktEnabled = false
        await failure(.unavailable) { _ = try await f.quote() }; equal(f.server.methods, [])
    }
    func testChangedSelectedWalletRejectsQuoteBeforeRPC() async throws {
        let f = try make(); f.selected = nil
        await failure(.wrongWalletOrNetwork) { _ = try await f.quote() }; equal(f.server.methods, [])
    }
    func testZeroInputIsRejectedBeforeRPC() async throws {
        let f = try make(); await failure(.invalidAmount) { _ = try await f.quote(input: 0) }; equal(f.server.methods, [])
    }
    func testSlippageOutsideMobileBoundsIsRejectedBeforeRPC() async throws {
        let f = try make()
        for value in [UInt16(0), UInt16.max] { await failure(.invalidSlippage) { _ = try await f.quote(slippage: value) } }
        equal(f.server.methods, [])
    }
    func testClosedStoredMarketBlocksQuoteEvenWhenRuntimeQuoteExists() async throws {
        let f = try make(); f.server.market = f.markets["Locked500"]!
        await failure(.marketUnavailable) { _ = try await f.quote() }; equal(f.extrinsics.estimateCount, 0)
    }
    func testFinalizedHeightAtCloseBlockTreatsOpenStorageAsLocked() async throws {
        let f = try make(); f.server.market = f.markets["Open400"]!
        await failure(.marketUnavailable) { _ = try await f.quote() }; equal(f.extrinsics.estimateCount, 0)
    }
    func testMissingMarketStorageIsUnavailable() async throws {
        let f = try make(); f.server.market = nil
        await failure { _ = try await f.quote() }; equal(f.extrinsics.estimateCount, 0)
    }
    func testMalformedMarketStorageCannotGenerateAQuote() async throws {
        let f = try make(); f.server.market = "0x01"
        await failure { _ = try await f.quote() }; equal(f.extrinsics.estimateCount, 0)
    }
    func testWrongRuntimeMarketIdentityCannotGenerateAQuote() async throws {
        let f = try make(); f.server.stateId = 43
        await failure { _ = try await f.quote() }; equal(f.extrinsics.estimateCount, 0)
    }
    func testBuyQuoteMustEchoMarketOutcomeAndInput() async throws {
        let f = try make()
        for overrides: [String: Any] in [["marketId": 43], ["outcome": "No"], ["collateralIn": "999"], ["sharesOut": "0"]] {
            f.server.buyOverrides = overrides; await failure(.invalidQuote) { _ = try await f.quote() }
        }
        equal(f.extrinsics.estimateCount, 0)
    }
    func testSellQuoteMustEchoMarketOutcomeAndInput() async throws {
        let f = try make()
        for overrides: [String: Any] in [["marketId": 43], ["outcome": "Yes"], ["sharesIn": "999"], ["collateralOut": "0"]] {
            f.server.sellOverrides = overrides; await failure(.invalidQuote) { _ = try await f.quote(side: .sell, outcome: .no) }
        }
        equal(f.extrinsics.estimateCount, 0)
    }
    func testBuyRequiresEnoughCollateral() async throws {
        let f = try make(); f.server.kusd = "999"; await failure(.insufficientKUSD) { _ = try await f.quote() }
    }
    func testBothQuoteSidesRequireEnoughXorForTheNetworkFee() async throws {
        let f = try make(); f.server.xor = "6"
        await failure(.insufficientXOR) { _ = try await f.quote() }; await failure(.insufficientXOR) { _ = try await f.quote(side: .sell, outcome: .no) }
    }
    func testSellCannotUseSharesFromTheOppositeOutcome() async throws {
        let f = try make(); f.server.noShares = "999"
        await failure(.insufficientShares) { _ = try await f.quote(side: .sell, outcome: .no) }; equal(f.extrinsics.estimateCount, 0)
    }
    func testAbsentPositionDoesNotInventSellableShares() async throws {
        let f = try make(); f.server.claimMissing = true
        await failure(.insufficientShares) { _ = try await f.quote(side: .sell, outcome: .no) }; equal(f.extrinsics.estimateCount, 0)
    }
    func testFeeFailureAndMalformedFeesPreventReview() async throws {
        let f = try make(); f.extrinsics.failure = CoordinatorFailure.offline
        await failure { _ = try await f.quote() }; f.extrinsics.failure = nil
        for fee in ["0", "-1", "bad", "1.5"] { f.extrinsics.rawFee = fee; await failure { _ = try await f.quote() } }
    }
    func testCancelledQuoteCannotReturnAConfirmationAfterTheFeeCallback() async throws {
        let f = try make(); let waiting = expectation(description: "fee callback retained")
        f.extrinsics.holdFee = true; f.extrinsics.onFee = { waiting.fulfill() }
        let task = Task { try await f.quote() }
        await fulfillment(of: [waiting], timeout: 3)
        for _ in 0..<100 {
            if f.server.methods.filter({ $0 == SoraPassport.RPCMethod.freeBalance }).count == 2 { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 30_000_000)
        task.cancel(); f.extrinsics.heldFee?(.success("7"))
        do { _ = try await task.value; XCTFail("Cancelled quote returned a confirmation") } catch { XCTAssertTrue(error is CancellationError) }
    }
    func testWalletChangeDuringFeeReadInvalidatesTheReview() async throws {
        let f = try make(); let waiting = expectation(description: "fee callback retained")
        f.extrinsics.holdFee = true; f.extrinsics.onFee = { waiting.fulfill() }
        let task = Task { try await f.quote() }; await fulfillment(of: [waiting], timeout: 3)
        f.selected = nil; f.extrinsics.heldFee?(.success("7"))
        await failure { _ = try await task.value }
    }
    func testFeatureDisabledDuringFeeReadInvalidatesTheReview() async throws {
        let f = try make(); let waiting = expectation(description: "fee callback retained")
        f.extrinsics.holdFee = true; f.extrinsics.onFee = { waiting.fulfill() }
        let task = Task { try await f.quote() }; await fulfillment(of: [waiting], timeout: 3)
        f.settings.polkamarktEnabled = false; f.extrinsics.heldFee?(.success("7"))
        await failure { _ = try await task.value }
    }
    func testFailedQuoteReleasesAdmissionForAnIndependentRetry() async throws {
        let f = try make(); f.extrinsics.failure = CoordinatorFailure.offline
        await failure { _ = try await f.quote() }; f.extrinsics.failure = nil
        equal(try await f.quote().output, 2222)
    }
    func testReviewWithoutAnAccountDoesNotRequestClaimables() async throws {
        let f = try make(); let review = try await f.subject.authoritativeMarketReview(account: nil, marketId: 42)
        equal(review.finalizedBlockHash, f.server.block); equal(review.state.finalizedStatus, .open); XCTAssertNil(review.claimable)
        XCTAssertFalse(f.server.methods.contains(PolkamarktRuntimeContract.RPC.claimable)); equal(f.extrinsics.estimateCount, 0)
    }
    func testAccountReviewBindsThePositionToItsOwnerAndMarket() async throws {
        let f = try make(); let review = try await f.subject.authoritativeMarketReview(account: f.account.address, marketId: 42)
        equal(review.claimable?.account, f.account.address); equal(review.claimable?.marketId, 42); equal(review.claimable?.yesShares, 2000)
    }
    func testExpiredReadOnlyMarketReviewUsesEffectiveLockedStatus() async throws {
        let f = try make(); f.server.market = f.markets["Open400"]!
        let state = try await f.subject.authoritativeState(marketId: 42); equal(state.finalizedStatus, .locked)
    }
    func testBatchClaimReviewUsesCanonicalMarketOrdering() async throws {
        let f = try make(); let review = try await f.subject.authoritativeClaimables(account: f.account.address, marketIds: [3, 1, 2])
        equal(review.claims.map(\.marketId), [1, 2, 3]); equal(review.account, f.account.address); equal(review.finalizedBlockHash, f.server.block)
    }
    func testBatchClaimReviewRejectsEmptyDuplicateAndOversizedRequests() async throws {
        let f = try make()
        for ids in [[UInt32](), [1, 1], Array(0...24).map(UInt32.init)] { await failure { _ = try await f.subject.authoritativeClaimables(account: f.account.address, marketIds: ids) } }
        equal(f.server.methods, [])
    }
    func testSingleClaimReviewKeepsAbsentPositionsNil() async throws {
        let f = try make(); f.server.claimMissing = true
        let claim = try await f.subject.authoritativeClaimable(account: f.account.address, marketId: 42); XCTAssertNil(claim)
    }
    func testClaimResponseForAnotherAccountIsRejected() async throws {
        let f = try make(); f.server.claimOwner = "unrelated"
        await failure { _ = try await f.subject.authoritativeClaimable(account: f.account.address, marketId: 42) }
    }
    func testCoordinatorRequiresARealFacadeAndOperationFactory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try PolkamarktPendingStore(baseURL: directory)
        XCTAssertNil(PolkamarktTransactionCoordinator(walletContext: WalletContextMock(), pendingStore: store))
    }
}
private enum CoordinatorFailure: Swift.Error { case offline, unexpected }
@MainActor
private final class CoordinatorFixture {
    let settings = InMemorySettingsManager(), server = CoordinatorServer(), extrinsics = CoordinatorExtrinsics()
    let account: AccountItem
    var selected: AccountItem?
    let directory: URL, session: URLSession, engine: Sora2BoundedHTTPJSONRPCEngine, runtime: CoordinatorRuntime
    let markets: [String: String]
    var subject: PolkamarktTransactionCoordinator!
    var context: CoordinatorContext!
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let metadata = try! Data(contentsOf: root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec130.scale"))
    static let coder: Result<RuntimeCoderFactory, Swift.Error> = Result {
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(chainId: PIIndexerClient.soraMainnetGenesis,
            runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(chain: PIIndexerClient.soraMainnetGenesis, version: 130, txVersion: 130, metadata: metadata, resolver: nil),
            ownTypes: Data(contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")), dataHasher: .twox256)
        return RuntimeCoderFactory(catalog: snapshot.typeRegistryCatalog, specVersion: 130, txVersion: 130, metadata: snapshot.metadata)
    }
    init() throws {
        let key = Data(repeating: 3, count: 32)
        account = AccountItem(address: try SS58AddressFactory().addressFromAccountId(data: key, type: SoraPassport.Chain.sora.addressType()), cryptoType: .sr25519, networkType: SoraPassport.Chain.sora.addressType(), username: "Public fixture", publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: false)
        selected = account; directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.root.appendingPathComponent("Fixtures/Modernization/polkamarkt-market-storage-v130.json"))) as! [String: Any]
        markets = object["markets"] as! [String: String]
        server.market = markets["Open500"]!; server.metadataHex = Self.metadata.toHex(includePrefix: true); server.owner = account.address
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [CoordinatorURLProtocol.self]
        session = URLSession(configuration: configuration)
        CoordinatorURLProtocol.handler = { [server] in try server.response($0) }
        engine = Sora2BoundedHTTPJSONRPCEngine(nodeURL: URL(string: "https://polkamarkt.test")!, session: session)
        runtime = CoordinatorRuntime(coder: try Self.coder.get())
        let accountSettings = WalletAccountSettings(accountId: key.toHex(), assets: [])
        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
        let chain = AnyDataProviderRepository(InMemoryDataProviderRepository<ChainStorageItem>())
        let ids = try ChainStorageIdFactory(chain: .sora); let signer = CoordinatorNoSigner()
        let node = WalletNetworkOperationFactory(engine: engine, requestFactory: requestFactory, runtimeService: runtime, accountSettings: accountSettings, cryptoType: .sr25519, accountSigner: signer, extrinsicService: extrinsics, dummySigner: signer, chainStorage: chain, localStorageIdFactory: ids)
        let facade = WalletNetworkFacade(accountSettings: accountSettings, nodeOperationFactory: node, coingeckoOperationFactory: CoordinatorPrices(), polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactory(engine: engine), chainStorage: chain, localStorageIdFactory: ids, txStorage: AnyDataProviderRepository(InMemoryDataProviderRepository<TransactionHistoryItem>()), contactsOperationFactory: CoordinatorContacts(), accountsRepository: AnyDataProviderRepository(InMemoryDataProviderRepository<AccountItem>()), address: account.address, networkType: SoraPassport.Chain.sora.addressType(), assetManager: CoordinatorAssets(), totalPriceAssetId: nil, runtimeService: runtime, requestFactory: requestFactory, engine: engine, demeterFarmingService: CoordinatorFarms())
        context = CoordinatorContext(facade: facade); settings.polkamarktEnabled = true
        subject = PolkamarktTransactionCoordinator(walletContext: context, pendingStore: try PolkamarktPendingStore(baseURL: directory), settings: settings, selectedAccount: { [weak self] in self?.selected })
    }
    func quote(side: PolkamarktSide = .buy, outcome: PolkamarktOutcome = .yes, input: BigUInt = 1000, slippage: UInt16 = 100) async throws -> PolkamarktQuoteConfirmation {
        try await subject.quote(account: account.address, marketId: 42, outcome: outcome, side: side, input: input, slippageBasisPoints: slippage)
    }
    func cleanup() { session.invalidateAndCancel(); CoordinatorURLProtocol.handler = nil; try? FileManager.default.removeItem(at: directory) }
}
private final class CoordinatorContext: CommonWalletContextProtocol {
    let facade: WalletNetworkFacade
    init(facade: WalletNetworkFacade) { self.facade = facade }
    var networkOperationFactory: WalletNetworkOperationFactoryProtocol { facade }
    func prepareAccountUpdateCommand() -> WalletCommandProtocol { WalletCommandMock() }
    func prepareLanguageSwitchCommand(with newLanguage: WalletLanguage) -> WalletCommandProtocol { WalletCommandMock() }
}
private final class CoordinatorRuntime: SoraPassport.RuntimeCodingServiceProtocol {
    let coder: RuntimeCoderFactoryProtocol; var failure: Swift.Error?
    init(coder: RuntimeCoderFactoryProtocol) { self.coder = coder }
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> { ClosureOperation { if let failure = self.failure { throw failure }; return self.coder } }
}
private final class CoordinatorServer {
    let block = "0x" + String(repeating: "ab", count: 32)
    var owner = "", claimOwner: String?, market: String?, metadataHex = "", genesis = PIIndexerClient.soraMainnetGenesis
    var stateId = 42, kusd = "10000", xor = "20000", yesShares = "2000", noShares = "1500", claimMissing = false
    var buyOverrides = [String: Any](), sellOverrides = [String: Any]()
    private let lock = NSLock(); private var recorded = [String]()
    var methods: [String] { lock.lock(); defer { lock.unlock() }; return recorded }
    func response(_ request: URLRequest) throws -> Data {
        let body: Data
        if let data = request.httpBody { body = data }
        else if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }; var data = Data(); var buffer = [UInt8](repeating: 0, count: 8192)
            while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(buffer, count: count) }; body = data
        } else { throw CoordinatorFailure.unexpected }
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any]); let method = try XCTUnwrap(object["method"] as? String)
        let params = object["params"] as? [Any] ?? []; lock.lock(); recorded.append(method); lock.unlock()
        let result: Any
        switch method {
        case SoraPassport.RPCMethod.getBlockHash: result = genesis
        case SoraPassport.RPCMethod.getRuntimeMetadata: result = metadataHex
        case SoraPassport.RPCMethod.getHead: result = block
        case SoraPassport.RPCMethod.getHeader: result = ["number": "0x190", "parentHash": block, "extrinsicsRoot": block, "stateRoot": block, "digest": ["logs": []]]
        case SoraPassport.RPCMethod.queryStorageAt:
            let keys = try XCTUnwrap(params.first as? [String]); XCTAssertEqual(keys, ["0x7c9df7ef418f869f0ab365233bda527fd8426954fc0e154310293fc43493f5829017d1c733ec2aeaa6fd0230614e397e2a000000"]); result = [["block": block, "changes": keys.map { [$0, market as Any? ?? NSNull()] }]]
        case PolkamarktRuntimeContract.RPC.marketState:
            result = ["marketId": stateId, "mechanism": "DynamicParimutuel", "virtualDepth": "100", "realYesShares": "6000", "realNoShares": "4000", "dpmCollateral": "10000", "marginalYesPriceBps": 5500, "marginalNoPriceBps": 4500, "impliedYesProbabilityBps": 6000, "impliedNoProbabilityBps": 4000]
        case PolkamarktRuntimeContract.RPC.quoteBuy:
            result = ["marketId": 42, "outcome": "Yes", "collateralIn": "1000", "feeAmount": "5", "pricingCollateral": "995", "sharesOut": "2222"].merging(buyOverrides) { _, new in new }
        case PolkamarktRuntimeContract.RPC.quoteSell:
            result = ["marketId": 42, "outcome": "No", "sharesIn": "1000", "grossCollateralOut": "556", "feeAmount": "1", "collateralOut": "555"].merging(sellOverrides) { _, new in new }
        case PolkamarktRuntimeContract.RPC.claimable:
            result = claimMissing ? NSNull() : ["marketId": params[1], "account": claimOwner ?? owner, "status": "Open", "resolutionOutcome": NSNull(), "yesShares": yesShares, "noShares": noShares, "netCollateralPaid": "900", "traderPayout": "0", "claimablePayout": "0", "creatorFees": "0", "isCreator": false]
        case SoraPassport.RPCMethod.freeBalance:
            result = ["balance": (params[1] as? String) == WalletAssetId.xor.rawValue ? xor : kusd]
        default: throw CoordinatorFailure.unexpected
        }
        return try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": object["id"]!, "result": result])
    }
}
private final class CoordinatorURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> Data)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let data = try Self.handler?(request) ?? { throw CoordinatorFailure.unexpected }()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed); client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private final class CoordinatorExtrinsics: ExtrinsicServiceProtocol {
    var rawFee = "7"
    var holdFee = false, heldFee: EstimateFeeClosure?, onFee: (() -> Void)?
    var failure: Error?
    var builders: [CoordinatorBuilder] = []
    var estimateCount = 0
    var prepareCount = 0
    var submitCount = 0
    var preparedSubmitCount = 0
    var cancelAfterPrepare = false
    var prepared: PreparedExtrinsicSubmission?
    let call = CoordinatorCall()
    private func record(_ closure: ExtrinsicBuilderClosure) throws {
        let builder = CoordinatorBuilder(); _ = try closure(builder); builders.append(builder)
        if let failure { throw failure }
    }
    func estimateFee(_ closure: @escaping ExtrinsicBuilderClosure, runningIn queue: DispatchQueue, completion: @escaping EstimateFeeClosure) {
        estimateCount += 1
        do { try record(closure); if holdFee { heldFee = completion; onFee?() } else { completion(.success(rawFee)) } } catch { completion(.failure(error)) }
    }
    func prepareAndEstimateFee(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
                               preSigningValidation: @escaping () throws -> Void, runningIn queue: DispatchQueue,
                               completion: @escaping (Result<PreparedExtrinsicFeeQualification, Error>) -> Void) -> CancellableCall {
        prepareCount += 1
        do {
            try preSigningValidation(); try record(closure)
            let bytes = Data([1, 2, 3, 4])
            let result = PreparedExtrinsicSubmission(data: bytes, hash: try bytes.blake2b32().toHex(includePrefix: true))
            prepared = result
            if cancelAfterPrepare { withUnsafeCurrentTask { $0?.cancel() } }
            completion(.success(PreparedExtrinsicFeeQualification(prepared: result, rawFee: rawFee)))
        } catch { completion(.failure(error)) }
        return call
    }
    func prepareAndEstimateFee(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol,
        lifecycleLease: WalletLifecycleLease?, runtimeValidation: ((RuntimeCoderFactoryProtocol) throws -> Void)?,
        finalizedHeadValidation: ((String) throws -> Void)?, preSigningValidation: @escaping () throws -> Void,
        runningIn queue: DispatchQueue, completion: @escaping (Result<PreparedExtrinsicFeeQualification, Error>) -> Void) -> CancellableCall {
        XCTFail("Unexpected lifecycle preparation"); completion(.failure(CoordinatorFailure.unexpected)); return call
    }
    func submit(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol, runningIn queue: DispatchQueue,
                completion: @escaping ExtrinsicSubmitClosure) {
        submitCount += 1
        do { try record(closure); completion(.success("0x" + String(repeating: "0a", count: 32)), "0x" + String(repeating: "0a", count: 32), nil) }
        catch { completion(.failure(error), nil, nil) }
    }
    func submit(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol, lifecycleLease: WalletLifecycleLease?,
                runningIn queue: DispatchQueue, completion: @escaping ExtrinsicSubmitClosure) {
        XCTFail("Unexpected lifecycle submission"); completion(.failure(CoordinatorFailure.unexpected), nil, nil)
    }
    func prepare(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol, runningIn queue: DispatchQueue,
                 completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void) {
        XCTFail("Unexpected unqualified preparation"); completion(.failure(CoordinatorFailure.unexpected))
    }
    func prepare(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol, lifecycleLease: WalletLifecycleLease?,
        runtimeValidation: ((RuntimeCoderFactoryProtocol) throws -> Void)?, preSigningValidation: (() throws -> Void)?,
        runningIn queue: DispatchQueue, completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void) {
        XCTFail("Unexpected lifecycle preparation"); completion(.failure(CoordinatorFailure.unexpected))
    }
    func submitPrepared(_ prepared: PreparedExtrinsicSubmission, retainingTransportWitness: Bool, expectedRawFee: String,
        preTransportValidation: @escaping () throws -> Void, runningIn queue: DispatchQueue,
        completion: @escaping (Result<String, Error>) -> Void) -> CancellableCall {
        preparedSubmitCount += 1; XCTFail("Unexpected transport"); completion(.failure(CoordinatorFailure.unexpected)); return call
    }
}
private final class CoordinatorBuilder: SoraPassport.ExtrinsicBuilderProtocol {
    var calls: [JSON] = []
    var atomicSelections: [Bool] = []
    func with<A: Codable>(address: A) throws -> Self { XCTFail("Unexpected address binding"); return self }
    func with(nonce: UInt32) -> Self { XCTFail("Unexpected nonce"); return self }
    func with(era: Era, blockHash: String) -> Self { XCTFail("Unexpected era"); return self }
    func with(tip: BigUInt) -> Self { XCTFail("Unexpected tip"); return self }
    func with(shouldUseAtomicBatch: Bool) -> Self { atomicSelections.append(shouldUseAtomicBatch); return self }
    func adding<T: RuntimeCallable>(call: T) throws -> Self { let encoded = try JSONEncoder.scaleCompatible().encode(SoraPassport.EncodingContainer(value: call)); calls.append(try JSONDecoder.scaleCompatible(snakeCase: false).decode(SoraPassport.JsonContainer.self, from: encoded).value); return self }
    func adding(rawCall: Data) throws -> Self { XCTFail("Unexpected raw call"); throw CoordinatorFailure.unexpected }
    func signing(by signer: (Data) throws -> Data, of type: SoraPassport.CryptoType, using encoder: DynamicScaleEncoding,
                 metadata: RuntimeMetadata) throws -> Self { XCTFail("Unexpected signing"); throw CoordinatorFailure.unexpected }
    func buildExtrinsic(metadata: RuntimeMetadata) throws -> Extrinsic { XCTFail("Unexpected extrinsic build"); throw CoordinatorFailure.unexpected }
    func build(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws -> Data { throw CoordinatorFailure.unexpected }
    func buildSignature(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws -> Data { throw CoordinatorFailure.unexpected }
}
private final class CoordinatorNoSigner: SigningWrapperProtocol {
    func sign(_ originalData: Data) throws -> IRSignatureProtocol { XCTFail("No signing is permitted in these factory tests"); throw CoordinatorFailure.unexpected }
}

private final class CoordinatorCall: CancellableCall { func cancel() {} }

private final class CoordinatorPrices: CoingeckoOperationFactoryProtocol {
    var requests = [[String]](), values = [SoraPassport.PriceData](), failure: Swift.Error?
    func fetchPriceOperation(for tokenIds: [String]) -> BaseOperation<[SoraPassport.PriceData]> {
        requests.append(tokenIds)
        return ClosureOperation { if let failure = self.failure { throw failure }; return self.values }
    }
}
private final class CoordinatorContacts: WalletContactOperationFactoryProtocol {
    var items = [ContactItem](), failure: Swift.Error?
    func saveByAddressOperation(_ address: String) -> CompoundOperationWrapper<Void> { XCTFail("Unexpected contact mutation"); return .init(targetOperation: ClosureOperation { () }) }
    func fetchContactsOperation() -> CompoundOperationWrapper<[ContactItem]> {
        .init(targetOperation: ClosureOperation { if let failure = self.failure { throw failure }; return self.items })
    }
}
private final class CoordinatorAssets: AssetManagerProtocol {
    static var networkAssets = [AssetInfo]()
    var items = [(WalletAssetId.xor, "XOR"), (.val, "VAL")].map { AssetInfo(id: $0.0.rawValue, symbol: $0.1, chainId: "", precision: 18, icon: nil, displayName: $0.1, visible: true) }
    func assetInfo(for identifier: String) -> AssetInfo? { items.first { $0.identifier == identifier } }
    func getAssetList() -> [AssetInfo]? { items }
    func updateAssetList(_ list: [AssetInfo]) { items = list }
    func saveAssetList(_ list: [AssetInfo]) { items = list }
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { UInt(items.count) }
    func setup(for accountSettings: SelectedWalletSettings) {}
}
private final class CoordinatorFarms: DemeterFarmingServiceProtocol {
    var failure: Swift.Error?, reads = [Data]()
    func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?) async -> [UserFarm] { [] }
    func loadUserFarmInfos(baseAssetId: String?, targetAssetId: String?, accountId: Data) async throws -> [UserFarm] { reads.append(accountId); if let failure { throw failure }; return [] }
    func getAllFarms() async throws -> [Farm] { [] }
    func getFarm(with id: String) -> Farm? { nil }
    func getFarmDetails(baseAssetId: String, poolAssetId: String, rewardAssetId: String) async throws -> [Farm] { [] }
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) { completion([]) }
}
