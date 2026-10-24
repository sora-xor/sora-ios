// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
import RobinHood
import SSFUtils
import XCTest
@testable import SoraPassport

/// DEX ids are read from `DEXManager.DEXInfos` instead of being hard-coded to 0 and 1.
/// Mainnet today: 0 XOR, 1 XSTUSD, 2 KUSD, 3 (synthetic base 0x006a…).
final class DexInfoServiceTests: XCTestCase {
    private static let dex3Base = "0x006a271832f44c93bd8692584d85415f0f3dccef9748fecd129442c8edcb4361"
    private static let mainnet: [(UInt32, String)] = [
        (0, WalletAssetId.xor.rawValue),
        (1, WalletAssetId.xstusd.rawValue),
        (2, WalletAssetId.kusd.rawValue),
        (3, dex3Base)
    ]

    // MARK: - Fakes

    /// Answers JSON-RPC calls from a closure, asynchronously, like a node.
    private final class FakeRPCEngine: JSONRPCEngine {
        var url: URL? = URL(string: "wss://node.invalid")
        var pendingEngineRequests: [JSONRPCRequest] { [] }
        private let handler: (String, [Any]) -> Any?
        private let lock = NSLock()
        private var requestId: UInt16 = 0
        private var recorded: [(method: String, params: [Any])] = []

        init(handler: @escaping (String, [Any]) -> Any?) {
            self.handler = handler
        }

        var calls: [(method: String, params: [Any])] {
            lock.lock()
            defer { lock.unlock() }
            return recorded
        }

        func callMethod<P: Codable, T: Decodable>(
            _ method: String,
            params: P?,
            options _: JSONRPCOptions,
            completion closure: ((Result<T, Error>) -> Void)?
        ) throws -> UInt16 {
            var array: [Any] = []
            if let params,
               let data = try? JSONEncoder().encode(params),
               let decoded = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [Any] {
                array = decoded
            }
            lock.lock()
            recorded.append((method, array))
            requestId += 1
            let id = requestId
            lock.unlock()

            let response = handler(method, array)
            DispatchQueue.global().async {
                guard let response,
                      let data = try? JSONSerialization.data(withJSONObject: response, options: [.fragmentsAllowed]),
                      let value = try? JSONDecoder().decode(T.self, from: data) else {
                    closure?(.failure(NSError(domain: "FakeRPC", code: 1)))
                    return
                }
                closure?(.success(value))
            }
            return id
        }

        func subscribe<P: Codable, T: Decodable>(
            _: String,
            params _: P?,
            updateClosure _: @escaping (T) -> Void,
            failureClosure _: @escaping (Error, Bool) -> Void
        ) throws -> UInt16 {
            throw NSError(domain: "FakeRPC", code: 2)
        }

        func cancelForIdentifier(_: UInt16) {}
        func generateRequestId() -> UInt16 { 0 }
        func addSubscription(_: JSONRPCSubscribing) {}
        func reconnect(url _: URL) {}
        func connectIfNeeded() {}
        func disconnectIfNeeded() {}
        func unsubsribe(_: UInt16) throws {}
    }

    private final class StubLoader: DexInfoLoading {
        private let lock = NSLock()
        private var count = 0
        var result: Result<[DexInfo], Error>
        var holds = false
        private var pending: [(Result<[DexInfo], Error>) -> Void] = []

        init(_ result: Result<[DexInfo], Error>) { self.result = result }

        var loads: Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }

        func loadDexInfos(completion: @escaping (Result<[DexInfo], Error>) -> Void) {
            lock.lock()
            count += 1
            if holds {
                pending.append(completion)
                lock.unlock()
                return
            }
            lock.unlock()
            completion(result)
        }

        func release() {
            lock.lock()
            let waiting = pending
            pending = []
            lock.unlock()
            waiting.forEach { $0(result) }
        }
    }

    private final class PresenterSpy: PolkaswapMainInteractorOutputProtocol {
        var onPath: ((Bool) -> Void)?
        var onSources: (([String]) -> Void)?
        var onQuote: ((SwapValues?, UInt32) -> Void)?

        func didCheckPath(fromAssetId _: String, toAssetId _: String, isAvailable: Bool) { onPath?(isAvailable) }
        func didLoadMarketSources(_ sources: [String], fromAssetId _: String, toAssetId _: String) { onSources?(sources) }
        func didLoadQuote(_ quote: SwapValues?, dexId: UInt32, params _: PolkaswapMainInteractorQuoteParams) {
            onQuote?(quote, dexId)
        }
        func didUpdatePoolSubscription() {}
    }

    // MARK: - Chain storage

    private func prefix() throws -> Data {
        try StorageKeyFactory().createStorageKey(moduleName: "DEXManager", storageName: "DEXInfos")
    }

    private func storageKey(_ id: UInt32) throws -> Data {
        var littleEndian = id.littleEndian
        let idBytes = Data(bytes: &littleEndian, count: 4)
        return try StorageKeyFactory().createStorageKey(
            moduleName: "DEXManager",
            storageName: "DEXInfos",
            key: idBytes,
            hasher: .twox64Concat
        )
    }

    /// `DEXInfo { base_asset_id, synthetic_base_asset_id, is_public }`.
    private func storageValue(base: String) throws -> Data {
        try Data(hexStringSSF: base) + Data(hexStringSSF: WalletAssetId.xst.rawValue) + Data([1])
    }

    private func mainnetEngine(failQueries: Bool = false) throws -> FakeRPCEngine {
        let prefixHex = try prefix().toHex(includePrefix: true)
        var changes: [[String]] = []
        for (id, base) in Self.mainnet {
            changes.append([try storageKey(id).toHex(includePrefix: true), try storageValue(base: base).toHex(includePrefix: true)])
        }
        let keys = changes.map { $0[0] }
        return FakeRPCEngine { method, params in
            switch method {
            case SoraPassport.RPCMethod.getStorageKeysPaged:
                return (params.first as? String) == prefixHex ? keys : nil
            case SoraPassport.RPCMethod.queryStorageAt:
                return failQueries ? nil : [["block": "0x01", "changes": changes]]
            default:
                return nil
            }
        }
    }

    // MARK: - Decoding

    func testDecodesMainnetDexInfos() throws {
        let prefix = try prefix()
        var entries: [(key: Data, value: Data?)] = []
        for (id, base) in Self.mainnet.reversed() {
            entries.append((try storageKey(id), try storageValue(base: base)))
        }
        // Entries of another shape are skipped.
        entries.append((try storageKey(9), Data(repeating: 1, count: 20)))
        entries.append((try storageKey(10), nil))
        entries.append((prefix + Data(repeating: 0, count: 6), try storageValue(base: WalletAssetId.val.rawValue)))
        entries.append((Data(repeating: 7, count: prefix.count) + Data(repeating: 0, count: 12),
                        try storageValue(base: WalletAssetId.val.rawValue)))

        let dexes = ChainDexInfoLoader.decode(entries, prefix: prefix)

        XCTAssertEqual(dexes, Self.mainnet.map { DexInfo(id: $0.0, baseAssetId: $0.1) })
    }

    func testLoaderReadsKeysThenValuesFromTheNode() throws {
        let engine = try mainnetEngine()
        let loader = ChainDexInfoLoader(engineProvider: { engine })
        let loaded = expectation(description: "loaded")
        var result: Result<[DexInfo], Error>?
        loader.loadDexInfos {
            result = $0
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 5)

        XCTAssertEqual(try result?.get(), Self.mainnet.map { DexInfo(id: $0.0, baseAssetId: $0.1) })
        XCTAssertEqual(engine.calls.map(\.method), [SoraPassport.RPCMethod.getStorageKeysPaged, SoraPassport.RPCMethod.queryStorageAt])
    }

    func testLoaderFailsWithoutAConnectionOrAnswer() throws {
        for engine in [nil, try mainnetEngine(failQueries: true)] as [FakeRPCEngine?] {
            let loader = ChainDexInfoLoader(engineProvider: { engine })
            let loaded = expectation(description: "loaded")
            loader.loadDexInfos { result in
                if case .success = result {
                    XCTFail("a read without an answer must fail")
                }
                loaded.fulfill()
            }
            wait(for: [loaded], timeout: 5)
        }
    }

    // MARK: - Service

    func testServiceUsesTheChainListAfterOneRead() async throws {
        let chain = Self.mainnet.map { DexInfo(id: $0.0, baseAssetId: $0.1) }
        let loader = StubLoader(.success(chain.reversed()))
        let service = DexInfoService(loader: loader)

        XCTAssertEqual(service.knownDexes, DexInfoService.genesisDexes)
        XCTAssertEqual(service.knownDexId(forBaseAssetId: WalletAssetId.xor.rawValue), 0)
        XCTAssertEqual(service.knownDexId(forBaseAssetId: WalletAssetId.xstusd.rawValue), 1)
        XCTAssertNil(service.knownDexId(forBaseAssetId: WalletAssetId.kusd.rawValue))

        let kusd = await service.dexId(forBaseAssetId: WalletAssetId.kusd.rawValue)
        XCTAssertEqual(kusd, 2)
        let dexes = await service.dexes()
        XCTAssertEqual(dexes, chain)
        XCTAssertEqual(service.knownDexId(forBaseAssetId: Self.dex3Base.uppercased().replacingOccurrences(of: "0X", with: "0x")), 3)
        XCTAssertEqual(loader.loads, 1)
    }

    func testUnknownBaseAssetIsReportedNotRetriedForever() async {
        let loader = StubLoader(.success(Self.mainnet.map { DexInfo(id: $0.0, baseAssetId: $0.1) }))
        let service = DexInfoService(loader: loader)

        let kxor = await service.dexId(forBaseAssetId: WalletAssetId.kxor)
        XCTAssertNil(kxor, "KXOR is not the base asset of any DEX")
        let again = await service.dexId(forBaseAssetId: WalletAssetId.kxor)
        XCTAssertNil(again)
        XCTAssertEqual(loader.loads, 1, "one chain read, no recursion")
    }

    func testFailedReadFallsBackToGenesisDexesAndRetriesLater() async {
        var clock = Date(timeIntervalSince1970: 1_000)
        let loader = StubLoader(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)))
        let service = DexInfoService(loader: loader, now: { clock })

        let first = await service.dexes()
        XCTAssertEqual(first, DexInfoService.genesisDexes)
        let xor = await service.dexId(forBaseAssetId: WalletAssetId.xor.rawValue)
        XCTAssertEqual(xor, 0)
        let kusd = await service.dexId(forBaseAssetId: WalletAssetId.kusd.rawValue)
        XCTAssertNil(kusd)
        XCTAssertEqual(loader.loads, 1, "no new read inside the retry interval")

        clock += DexInfoService.retryInterval + 1
        loader.result = .success(Self.mainnet.map { DexInfo(id: $0.0, baseAssetId: $0.1) })
        let later = await service.dexId(forBaseAssetId: WalletAssetId.kusd.rawValue)
        XCTAssertEqual(later, 2)
        XCTAssertEqual(loader.loads, 2)
    }

    func testConcurrentLookupsShareOneRead() {
        let loader = StubLoader(.success(Self.mainnet.map { DexInfo(id: $0.0, baseAssetId: $0.1) }))
        loader.holds = true
        let service = DexInfoService(loader: loader)
        let answered = expectation(description: "every caller answered")
        answered.expectedFulfillmentCount = 20
        DispatchQueue.concurrentPerform(iterations: 20) { _ in
            service.dexes { dexes in
                XCTAssertEqual(dexes.count, 4)
                answered.fulfill()
            }
        }
        loader.release()
        wait(for: [answered], timeout: 5)
        XCTAssertEqual(loader.loads, 1)
    }

    // MARK: - Swap interactor

    /// The pair exists only on DEX 2 (KUSD) and DEX 2 also quotes best: the path is
    /// available and the quote carries DEX id 2, which the swap is sent with.
    func testSwapUsesEveryChainDex() throws {
        let chainEngine = try mainnetEngine()
        let service = DexInfoService(loader: ChainDexInfoLoader(engineProvider: { chainEngine }))
        let swapEngine = FakeRPCEngine { method, params in
            let dexId = (params.first as? NSNumber)?.uint32Value
            switch method {
            case SoraPassport.RPCMethod.checkIsSwapPossible:
                return dexId == 2
            case SoraPassport.RPCMethod.availableMarketAlgorithms:
                return dexId == 2 ? ["XYKPool"] : (dexId == 0 ? ["XYKPool", "OrderBook"] : nil)
            case SoraPassport.RPCMethod.recalculateSwapValues:
                switch dexId {
                case 0: return ["amount": "100", "route": []]
                case 2: return ["amount": "120", "route": []]
                default: return nil
                }
            default:
                return nil
            }
        }
        let interactor = PolkaswapMainInteractor(
            operationManager: OperationManager(),
            eventCenter: EventCenter(),
            dexService: service
        )
        interactor.polkaswapNetworkFacade = PolkaswapNetworkOperationFactory(engine: swapEngine)
        let presenter = PresenterSpy()
        interactor.presenter = presenter

        let path = expectation(description: "path")
        presenter.onPath = { isAvailable in
            XCTAssertTrue(isAvailable)
            path.fulfill()
        }
        interactor.checkIsPathAvailable(fromAssetId: WalletAssetId.kusd.rawValue, toAssetId: Self.dex3Base)
        wait(for: [path], timeout: 5)

        let sources = expectation(description: "sources")
        presenter.onSources = { list in
            XCTAssertEqual(list, ["XYKPool", "OrderBook"])
            sources.fulfill()
        }
        interactor.loadMarketSources(fromAssetId: WalletAssetId.kusd.rawValue, toAssetId: Self.dex3Base)
        wait(for: [sources], timeout: 5)

        for (variant, expectedDex, expectedAmount) in [(SwapVariant.desiredInput, UInt32(2), "120"),
                                                       (.desiredOutput, 0, "100")] {
            let quoted = expectation(description: "quote \(variant)")
            presenter.onQuote = { quote, dexId in
                XCTAssertEqual(dexId, expectedDex)
                XCTAssertEqual(quote?.amount, expectedAmount)
                quoted.fulfill()
            }
            interactor.quote(params: PolkaswapMainInteractorQuoteParams(
                fromAssetId: WalletAssetId.kusd.rawValue,
                toAssetId: Self.dex3Base,
                amount: "1000",
                swapVariant: variant,
                liquiditySources: [],
                filterMode: .disabled
            ))
            wait(for: [quoted], timeout: 5)
        }

        let quotedDexes = Set(swapEngine.calls
            .filter { $0.method == SoraPassport.RPCMethod.recalculateSwapValues }
            .compactMap { ($0.params.first as? NSNumber)?.uint32Value })
        XCTAssertEqual(quotedDexes, [0, 1, 2, 3])
        withExtendedLifetime(presenter) {}
    }

    // MARK: - Liquidity

    func testLiquidityUsesTheBaseAssetsDexAndRefusesKXOR() throws {
        let assetManager = LiquidityAssetManagerStub()
        let supply = try LiquidityTransferInfoFactory.supply(
            baseAssetId: WalletAssetId.xstusd.rawValue,
            targetAssetId: WalletAssetId.val.rawValue,
            firstAssetAmount: 1,
            secondAssetAmount: 1,
            slippageTolerance: .defaultValue,
            transactionType: .liquidityAdd,
            fee: 0,
            assetManager: assetManager
        )
        XCTAssertEqual(supply.context?[TransactionContextKeys.dex], "1")

        XCTAssertThrowsError(try LiquidityTransferInfoFactory.supply(
            baseAssetId: WalletAssetId.kxor,
            targetAssetId: WalletAssetId.val.rawValue,
            firstAssetAmount: 1,
            secondAssetAmount: 1,
            slippageTolerance: .defaultValue,
            transactionType: .liquidityAdd,
            fee: 0,
            assetManager: assetManager
        )) { error in
            guard case LiquidityTransferInfoFactoryError.unknownDex = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }
}

/// Knows every asset; the liquidity factory only checks that the assets exist.
private final class LiquidityAssetManagerStub: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []

    func assetInfo(for identifier: String) -> AssetInfo? {
        AssetInfo(id: identifier, symbol: "T", chainId: "", precision: 18, icon: nil, displayName: nil, visible: true)
    }

    func getAssetList() -> [AssetInfo]? { [] }
    func updateAssetList(_: [AssetInfo]) {}
    func saveAssetList(_: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible _: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { 0 }
    func setup(for _: SelectedWalletSettings) {}
}
