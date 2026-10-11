// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CryptoKit
import Foundation
import Network
import RobinHood
import SoraKeystore
import SSFUtils
import XCTest
@testable import SoraPassport

/// Audit finding I1: startup waited on the splash for the remote configuration
/// and for the on-chain asset list of one saved node. A first request that
/// failed left an empty key list, and the loader then asked for the values of
/// no keys in an endless recursion. Startup now waits for no network answer;
/// the list is loaded in the background with a bounded, backed-off retry.
final class StartupNetworkTests: XCTestCase {

    // MARK: - A node that answers as the test says

    private enum Answer {
        case result(Any)
        case failure
        case silent
    }

    private struct Call {
        let id: UInt16
        let method: String
        let params: [Any]

        var isKeysPage: Bool { method == "state_getKeysPaged" }
        var isValueQuery: Bool { method == "state_queryStorageAt" }
        var startKey: String? { params.count > 2 ? params[2] as? String : nil }
        var queriedKeys: [String] { params.first as? [String] ?? [] }
    }

    /// Answers on the caller's thread, inside `callMethod`, unless told to stay
    /// silent. That is the hardest case for the loader: an answer that is
    /// handled inline would recurse.
    private final class StubNode: JSONRPCEngine, ConnectionStateReporting {
        var url: URL? = URL(string: "wss://node.invalid")
        var pendingEngineRequests: [JSONRPCRequest] { [] }

        private let lock = NSLock()
        private var nextId: UInt16 = 0
        private var recorded: [Call] = []
        private var cancelledIds: [UInt16] = []
        private var held: [UInt16: (Answer) -> Void] = [:]
        private var currentState: WebSocketEngine.State = .connected
        private var respond: (Call) -> Answer = { _ in .silent }

        var state: WebSocketEngine.State {
            get { lock.lock(); defer { lock.unlock() }; return currentState }
            set { lock.lock(); currentState = newValue; lock.unlock() }
        }

        var answer: (Call) -> Answer {
            get { lock.lock(); defer { lock.unlock() }; return respond }
            set { lock.lock(); respond = newValue; lock.unlock() }
        }

        var calls: [Call] { lock.lock(); defer { lock.unlock() }; return recorded }
        var cancelled: [UInt16] { lock.lock(); defer { lock.unlock() }; return cancelledIds }
        var unanswered: [UInt16] { lock.lock(); defer { lock.unlock() }; return held.keys.sorted() }

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
            nextId += 1
            let call = Call(id: nextId, method: method, params: array)
            recorded.append(call)
            let respond = self.respond
            lock.unlock()

            let deliver: (Answer) -> Void = { answer in
                switch answer {
                case let .result(json):
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.fragmentsAllowed]),
                          let value = try? JSONDecoder().decode(T.self, from: data) else {
                        closure?(.failure(NSError(domain: "StubNode", code: 1)))
                        return
                    }
                    closure?(.success(value))
                case .failure:
                    closure?(.failure(NSError(domain: "StubNode", code: 2)))
                case .silent:
                    break
                }
            }
            let answer = respond(call)
            if case .silent = answer {
                lock.lock()
                held[call.id] = deliver
                lock.unlock()
            } else {
                deliver(answer)
            }
            return call.id
        }

        /// A late answer to a request that was left unanswered.
        func answerLate(_ id: UInt16, with answer: Answer) {
            lock.lock()
            let deliver = held.removeValue(forKey: id)
            lock.unlock()
            deliver?(answer)
        }

        func cancelForIdentifier(_ identifier: UInt16) {
            lock.lock()
            cancelledIds.append(identifier)
            lock.unlock()
        }

        func subscribe<P: Codable, T: Decodable>(
            _: String,
            params _: P?,
            updateClosure _: @escaping (T) -> Void,
            failureClosure _: @escaping (Error, Bool) -> Void
        ) throws -> UInt16 {
            throw NSError(domain: "StubNode", code: 3)
        }

        func generateRequestId() -> UInt16 { 0 }
        func addSubscription(_: JSONRPCSubscribing) {}
        func reconnect(url _: URL) {}
        func connectIfNeeded() {}
        func disconnectIfNeeded() {}
        func unsubsribe(_: UInt16) throws {}
    }

    // MARK: - Timers fired by the test

    private final class ManualTimers {
        private struct Entry {
            let delay: TimeInterval
            let deadline: TimeInterval
            let fire: () -> Void
            var isDone = false
        }

        private let lock = NSLock()
        private var entries: [Entry] = []
        private var clock: TimeInterval = 0

        var now: TimeInterval { lock.lock(); defer { lock.unlock() }; return clock }

        func advance(by interval: TimeInterval) {
            lock.lock()
            clock += interval
            lock.unlock()
        }

        var timer: AssetsInfoProvider.Timer {
            { [self] delay, fire in
                lock.lock()
                let index = entries.count
                entries.append(Entry(delay: delay, deadline: clock + delay, fire: fire))
                lock.unlock()
                return { [self] in
                    lock.lock()
                    entries[index].isDone = true
                    lock.unlock()
                }
            }
        }

        /// The waits of the timers that are running, oldest first.
        var pending: [TimeInterval] {
            lock.lock()
            defer { lock.unlock() }
            return entries.filter { !$0.isDone }.map(\.delay)
        }

        /// Lets the oldest running timer expire and moves the clock to its time.
        @discardableResult
        func fireNext() -> TimeInterval? {
            lock.lock()
            guard let index = entries.firstIndex(where: { !$0.isDone }) else {
                lock.unlock()
                return nil
            }
            entries[index].isDone = true
            let entry = entries[index]
            clock = max(clock, entry.deadline)
            lock.unlock()
            entry.fire()
            return entry.delay
        }
    }

    // MARK: - Fixtures

    private let queue = DispatchQueue(label: "StartupNetworkTests.provider")
    private let timers = ManualTimers()
    private let node = StubNode()
    private let prefix = try! StorageKeyFactory().assetsInfoKeysPaged().toHex(includePrefix: true)
    private var savedNetworkAssets: [AssetInfo] = []
    private var directory: URL!

    private let keysTimeout: TimeInterval = 7
    private let valuesTimeout: TimeInterval = 11

    override func setUpWithError() throws {
        savedNetworkAssets = AssetManager.networkAssets
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StartupNetworkTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        AssetManager.networkAssets = savedNetworkAssets
        try? FileManager.default.removeItem(at: directory)
    }

    private func policy(pageSize: UInt32 = 2, maximumPages: Int = 32) -> AssetsInfoProvider.RetryPolicy {
        AssetsInfoProvider.RetryPolicy(
            initialDelay: 2, multiplier: 2, maximumDelay: 60, jitter: 0, minimumRoundInterval: 5,
            keysPageSize: pageSize, maximumKeyPages: maximumPages,
            keysPageTimeout: keysTimeout, assetInfosTimeout: valuesTimeout
        )
    }

    private func makeProvider(
        connection: @escaping () -> AssetsInfoProvider.Connection?,
        policy: AssetsInfoProvider.RetryPolicy? = nil
    ) -> AssetsInfoProvider {
        AssetsInfoProvider(
            connection: connection,
            storageKeyFactory: StorageKeyFactory(),
            chainId: { "chain" },
            policy: policy ?? self.policy(),
            timer: timers.timer,
            now: { [timers] in timers.now },
            random: { 0 },
            logger: nil,
            queue: queue
        )
    }

    /// Runs everything the provider has queued, including the steps those
    /// steps queue: each pass lets at least one more step run.
    private func settle() {
        for _ in 0 ..< 64 {
            queue.sync {}
        }
    }

    private func key(_ assetId: String) -> String {
        prefix + String(repeating: "ab", count: 16) + assetId.dropFirst(2)
    }

    private func value(symbol: String, name: String, precision: UInt8 = 18) throws -> String {
        let encoder = ScaleEncoder()
        try symbol.encode(scaleEncoder: encoder)
        try name.encode(scaleEncoder: encoder)
        try precision.encode(scaleEncoder: encoder)
        try true.encode(scaleEncoder: encoder)
        return encoder.encode().toHex(includePrefix: true)
    }

    private var xorKey: String { key(WalletAssetId.xor.rawValue) }
    private var valKey: String { key(WalletAssetId.val.rawValue) }
    private var pswapKey: String { key(WalletAssetId.pswap.rawValue) }

    private func values(for keys: [String]) throws -> [Any] {
        let named: [String: (String, String)] = [
            xorKey: ("XOR", "SORA"), valKey: ("VAL", "SORA Validator Token"), pswapKey: ("PSWAP", "Polkaswap")
        ]
        let changes: [[Any]] = try keys.map { key in
            let (symbol, name) = try XCTUnwrap(named[key])
            return [key, try value(symbol: symbol, name: name)]
        }
        let update: [String: Any] = ["block": "0x" + String(repeating: "00", count: 32), "changes": changes]
        return [update]
    }

    /// A healthy node with three assets, served in pages of two.
    private func healthy() -> (Call) -> Answer {
        let pages: [String?: [String]] = [nil: [xorKey, valKey], valKey: [pswapKey]]
        return { [self] call in
            if call.isKeysPage {
                return .result(pages[call.startKey] ?? [])
            }
            if call.isValueQuery, let answer = try? values(for: call.queriedKeys) {
                return .result(answer)
            }
            return .failure
        }
    }

    private final class Loaded {
        private let lock = NSLock()
        private var lists: [[AssetInfo]] = []
        func add(_ list: [AssetInfo]) { lock.lock(); lists.append(list); lock.unlock() }
        var all: [[AssetInfo]] { lock.lock(); defer { lock.unlock() }; return lists }
    }

    // MARK: - Loader: first page fails, then the node recovers

    func testFailedFirstPageIsReloadedWhenTheNodeRecovers() throws {
        node.answer = { _ in .failure }
        let loaded = Loaded()
        let provider = makeProvider(connection: { [node] in node })
        provider.load { loaded.add($0) }
        settle()

        // The failed first page ends the attempt: no value query without keys.
        XCTAssertEqual(node.calls.count, 1)
        XCTAssertTrue(node.calls[0].isKeysPage)
        XCTAssertNil(node.calls[0].startKey)
        XCTAssertEqual(timers.pending, [2], "one retry timer and nothing else")
        XCTAssertTrue(loaded.all.isEmpty)

        node.answer = healthy()
        settle()
        XCTAssertEqual(node.calls.count, 1, "nothing is sent before the wait is over")

        timers.fireNext()
        settle()

        let calls = node.calls
        XCTAssertEqual(calls.count, 4)
        XCTAssertTrue(calls[1].isKeysPage)
        XCTAssertNil(calls[1].startKey, "the retry starts from the first page again")
        XCTAssertTrue(calls[2].isKeysPage)
        XCTAssertEqual(calls[2].startKey, valKey)
        XCTAssertTrue(calls[3].isValueQuery)
        XCTAssertEqual(calls[3].queriedKeys, [xorKey, valKey, pswapKey])

        XCTAssertEqual(loaded.all.count, 1, "the list is delivered once")
        let assets = try XCTUnwrap(loaded.all.first)
        XCTAssertEqual(assets.map(\.assetId), [
            WalletAssetId.xor.rawValue, WalletAssetId.val.rawValue, WalletAssetId.pswap.rawValue
        ])
        XCTAssertEqual(assets.map(\.symbol), ["XOR", "VAL", "PSWAP"])
        XCTAssertEqual(assets.map(\.precision), [18, 18, 18])
        XCTAssertTrue(timers.pending.isEmpty, "no timer is left running")
        XCTAssertTrue(node.cancelled.isEmpty)
        withExtendedLifetime(provider) {}
    }

    func testFirstPageTimeoutIsTakenOffTheNodeAndRetriedFromTheFirstPage() throws {
        node.answer = { _ in .silent }
        let loaded = Loaded()
        let provider = makeProvider(connection: { [node] in node })
        provider.load { loaded.add($0) }
        settle()

        XCTAssertEqual(node.calls.count, 1)
        XCTAssertEqual(timers.pending, [keysTimeout])

        timers.fireNext()
        settle()
        let timedOut = node.calls[0].id
        XCTAssertEqual(node.cancelled, [timedOut], "a request that timed out does not stay queued")
        XCTAssertEqual(node.calls.count, 1)
        XCTAssertEqual(timers.pending, [2])

        // The node comes back and answers the old request late: it is ignored.
        node.answerLate(timedOut, with: .result([xorKey]))
        settle()
        XCTAssertEqual(node.calls.count, 1)
        XCTAssertTrue(loaded.all.isEmpty)
        XCTAssertEqual(timers.pending, [2])

        node.answer = healthy()
        timers.fireNext()
        settle()
        XCTAssertNil(node.calls[1].startKey)
        XCTAssertEqual(node.calls.filter(\.isValueQuery).count, 1)
        XCTAssertEqual(loaded.all.first?.count, 3)
        withExtendedLifetime(provider) {}
    }

    func testAFailureOnALaterPageRestartsFromTheFirstPage() throws {
        // Page one arrives, page two fails (for example the connection drops).
        node.answer = { [xorKey, valKey] call in
            call.startKey == nil ? .result([xorKey, valKey]) : .failure
        }
        let loaded = Loaded()
        let provider = makeProvider(connection: { [node] in node })
        provider.load { loaded.add($0) }
        settle()
        XCTAssertEqual(node.calls.map(\.startKey), [nil, valKey])
        XCTAssertTrue(node.calls.allSatisfy(\.isKeysPage), "half a key list is never used")
        XCTAssertEqual(timers.pending, [2])

        node.answer = healthy()
        timers.fireNext()
        settle()
        XCTAssertEqual(node.calls.count, 5)
        XCTAssertNil(node.calls[2].startKey)
        XCTAssertEqual(node.calls[4].queriedKeys, [xorKey, valKey, pswapKey], "no key twice")
        XCTAssertEqual(loaded.all.first?.count, 3)
        withExtendedLifetime(provider) {}
    }

    // MARK: - Loader: the node never answers

    func testNodeThatNeverAnswersGetsOneRequestPerAttemptAndTheWaitHasACeiling() {
        node.answer = { _ in .silent }
        let loaded = Loaded()
        let provider = makeProvider(connection: { [node] in node })
        provider.load { loaded.add($0) }
        settle()

        var waits: [TimeInterval] = []
        for attempt in 1 ... 9 {
            XCTAssertEqual(node.calls.count, attempt)
            XCTAssertEqual(timers.pending, [keysTimeout])
            timers.fireNext() // the request times out
            settle()
            XCTAssertEqual(node.calls.count, attempt, "no request before the wait is over")
            XCTAssertEqual(timers.pending.count, 1)
            waits.append(timers.fireNext() ?? -1) // the wait is over
            settle()
        }

        XCTAssertEqual(waits, [2, 4, 8, 16, 32, 60, 60, 60, 60])
        let calls = node.calls
        XCTAssertEqual(calls.count, 10)
        XCTAssertTrue(calls.allSatisfy { $0.isKeysPage && $0.startKey == nil })
        XCTAssertEqual(node.cancelled, calls.dropLast().map(\.id), "every timed out request was taken off the node")
        XCTAssertEqual(node.unanswered.count, 10)
        XCTAssertTrue(loaded.all.isEmpty)

        // Without a timer nothing happens: there is no loop that keeps asking.
        settle()
        XCTAssertEqual(node.calls.count, 10)
        withExtendedLifetime(provider) {}
    }

    // MARK: - Loader: the node answers with an empty list

    func testEmptyAnswersNeverLeadToAValueQueryWithoutKeysAndBackOff() throws {
        // This is the state that flooded a returning node: it has no keys to give.
        node.answer = { call in call.isKeysPage ? .result([String]()) : .result([Any]()) }
        let loaded = Loaded()
        let provider = makeProvider(connection: { [node] in node })
        provider.load { loaded.add($0) }
        settle()

        XCTAssertEqual(node.calls.count, 1)
        XCTAssertEqual(timers.pending, [2])
        XCTAssertEqual(timers.fireNext(), 2)
        settle()
        XCTAssertEqual(node.calls.count, 2)
        XCTAssertEqual(timers.pending, [4])
        XCTAssertTrue(node.calls.allSatisfy(\.isKeysPage), "no value query without keys")

        // Keys, but the node has no values for them.
        node.answer = { [xorKey] call in
            if call.isKeysPage { return .result([xorKey]) }
            let update: [String: Any] = ["block": "0x00", "changes": [[Any]]()]
            return .result([update])
        }
        XCTAssertEqual(timers.fireNext(), 4)
        settle()
        XCTAssertEqual(node.calls.count, 4)
        XCTAssertEqual(node.calls[3].queriedKeys, [xorKey])
        XCTAssertEqual(timers.pending, [8])

        // Keys, and an answer without any storage entry.
        node.answer = { [xorKey] call in
            call.isKeysPage ? .result([xorKey]) : .result([Any]())
        }
        XCTAssertEqual(timers.fireNext(), 8)
        settle()
        XCTAssertEqual(node.calls.count, 6)
        XCTAssertEqual(timers.pending, [16])
        XCTAssertTrue(loaded.all.isEmpty, "an empty list is never delivered")

        // Values that cannot be decoded are not assets either.
        node.answer = { [xorKey] call in
            if call.isKeysPage { return .result([xorKey]) }
            let update: [String: Any] = ["block": "0x00", "changes": [[xorKey, "0xff"]]]
            return .result([update])
        }
        XCTAssertEqual(timers.fireNext(), 16)
        settle()
        XCTAssertEqual(timers.pending, [32])
        XCTAssertTrue(loaded.all.isEmpty)

        node.answer = healthy()
        XCTAssertEqual(timers.fireNext(), 32)
        settle()
        XCTAssertEqual(loaded.all.first?.count, 3)
        XCTAssertTrue(node.calls.filter(\.isValueQuery).allSatisfy { !$0.queriedKeys.isEmpty })
        // Five failed attempts and one good one: 11 requests in all.
        XCTAssertEqual(node.calls.count, 11)
        withExtendedLifetime(provider) {}
    }

    func testANodeThatOnlyReturnsFullPagesEndsTheAttempt() {
        // Every page is full and new: the attempt ends at the page limit.
        let lock = NSLock()
        var served = 0
        node.answer = { [prefix] call in
            guard call.isKeysPage else { return .failure }
            lock.lock()
            served += 1
            let page = served
            lock.unlock()
            return .result((0 ..< 2).map { prefix + String(format: "%04x%04x", page, $0) })
        }
        let provider = makeProvider(connection: { [node] in node }, policy: policy(maximumPages: 3))
        provider.load { _ in XCTFail("nothing to deliver") }
        settle()
        XCTAssertEqual(node.calls.count, 3, "paging is bounded")
        XCTAssertTrue(node.calls.allSatisfy(\.isKeysPage))
        XCTAssertEqual(timers.pending, [2])
        withExtendedLifetime(provider) {}
    }

    func testANodeThatRepeatsAPageEndsTheAttemptAtOnce() {
        // The node ignores the start key and serves the first page again.
        node.answer = { [xorKey, valKey] call in
            call.isKeysPage ? .result([xorKey, valKey]) : .failure
        }
        let provider = makeProvider(connection: { [node] in node })
        provider.load { _ in XCTFail("nothing to deliver") }
        settle()
        XCTAssertEqual(node.calls.count, 2, "the repeated page is noticed on its first return")
        XCTAssertTrue(node.calls.allSatisfy(\.isKeysPage))
        XCTAssertEqual(timers.pending, [2])
        withExtendedLifetime(provider) {}
    }

    // MARK: - Loader: connection state, wake-ups, cancellation

    func testNothingIsSentUntilTheConnectionIsConnected() {
        node.answer = healthy()
        var current: StubNode?
        let lock = NSLock()
        let loaded = Loaded()
        let provider = makeProvider(connection: {
            lock.lock(); defer { lock.unlock() }
            return current
        })
        provider.load { loaded.add($0) }
        settle()
        XCTAssertTrue(node.calls.isEmpty)
        XCTAssertEqual(timers.pending, [2], "it looks again later")

        node.state = .connecting(attempt: 1)
        lock.lock(); current = node; lock.unlock()
        timers.fireNext()
        settle()
        XCTAssertTrue(node.calls.isEmpty, "a request to a connecting node would only be queued")
        XCTAssertEqual(timers.pending, [4])

        for state in [WebSocketEngine.State.notConnected, .waitingReconnection(attempt: 2), .notReachable] {
            node.state = state
            timers.fireNext()
            settle()
            XCTAssertTrue(node.calls.isEmpty)
        }
        XCTAssertEqual(timers.pending, [32])

        // The node connects: the loader is told and starts at once.
        node.state = .connected
        provider.retryNow(resettingBackoff: false)
        settle()
        XCTAssertEqual(node.calls.count, 3)
        XCTAssertEqual(loaded.all.first?.count, 3)
        XCTAssertTrue(timers.pending.isEmpty)
        withExtendedLifetime(provider) {}
    }

    func testRetryNowNeverBringsAttemptsCloserThanTheMinimumAndNeverPostpones() {
        node.answer = { _ in .failure }
        let provider = makeProvider(connection: { [node] in node })
        provider.load { _ in XCTFail("nothing to deliver") }
        settle()
        XCTAssertEqual(node.calls.count, 1) // attempt at 0 s, next at 2 s
        XCTAssertEqual(timers.pending, [2])

        // A flapping connection reports "connected" again and again.
        for _ in 0 ..< 20 {
            provider.retryNow(resettingBackoff: false)
        }
        settle()
        XCTAssertEqual(node.calls.count, 1, "no extra attempt within the minimum interval")
        XCTAssertEqual(timers.pending, [2], "and the planned attempt is not postponed")

        timers.fireNext() // 2 s: second attempt fails, next at 6 s
        settle()
        XCTAssertEqual(node.calls.count, 2)
        XCTAssertEqual(timers.pending, [4])
        provider.retryNow(resettingBackoff: true)
        settle()
        XCTAssertEqual(node.calls.count, 2)
        XCTAssertEqual(timers.pending, [4], "7 s would be later than the planned 6 s")

        timers.fireNext() // 6 s: third attempt fails; after a reset the wait is 2 s again
        settle()
        XCTAssertEqual(node.calls.count, 3)
        XCTAssertEqual(timers.pending, [2])
        timers.fireNext() // 8 s: fourth attempt fails, next at 12 s
        settle()
        timers.fireNext() // 12 s: fifth attempt fails, next at 20 s
        settle()
        XCTAssertEqual(node.calls.count, 5)
        XCTAssertEqual(timers.pending, [8])

        // 18 s: more than the minimum after the last attempt, and before the
        // planned one. A wake-up starts an attempt at once.
        timers.advance(by: 6)
        provider.retryNow(resettingBackoff: false)
        settle()
        XCTAssertEqual(node.calls.count, 6)
        XCTAssertEqual(timers.pending, [16], "it failed too: next at 34 s")

        // Right after an attempt a wake-up is held back to the minimum
        // interval (23 s), however often it comes.
        for _ in 0 ..< 20 {
            provider.retryNow(resettingBackoff: false)
        }
        settle()
        XCTAssertEqual(node.calls.count, 6)
        XCTAssertEqual(timers.pending, [5])
        timers.fireNext()
        settle()
        XCTAssertEqual(node.calls.count, 7)
        withExtendedLifetime(provider) {}
    }

    func testReleasingTheLoaderTakesItsRequestOffTheNodeAndStopsItsTimers() {
        node.answer = { _ in .silent }
        var provider: AssetsInfoProvider? = makeProvider(connection: { [node] in node })
        provider?.load { _ in XCTFail("a released loader delivers nothing") }
        settle()
        XCTAssertEqual(node.calls.count, 1)
        XCTAssertEqual(timers.pending.count, 1)

        weak var released: AssetsInfoProvider?
        released = provider
        provider = nil
        XCTAssertNil(released)
        XCTAssertEqual(node.cancelled, [node.calls[0].id])
        XCTAssertTrue(timers.pending.isEmpty)

        node.answerLate(node.calls[0].id, with: .result([xorKey]))
        settle()
        XCTAssertEqual(node.calls.count, 1)
    }

    func testCancelStopsTheLoader() {
        node.answer = { _ in .silent }
        let provider = makeProvider(connection: { [node] in node })
        provider.load { _ in XCTFail("a cancelled loader delivers nothing") }
        settle()
        provider.cancel()
        settle()
        XCTAssertEqual(node.cancelled, [node.calls[0].id])
        XCTAssertTrue(timers.pending.isEmpty)

        node.answer = healthy()
        provider.retryNow(resettingBackoff: true)
        provider.load { _ in XCTFail("a cancelled loader does not start again") }
        settle()
        XCTAssertEqual(node.calls.count, 1)
    }

    func testRetryWaitsDoubleUpToTheCeilingAndJitterOnlyShortensThem() {
        let policy = AssetsInfoProvider.RetryPolicy()
        XCTAssertEqual((1 ... 8).map { policy.delay(afterFailures: $0, random: 0) }, [2, 4, 8, 16, 32, 60, 60, 60])
        XCTAssertEqual(policy.delay(afterFailures: 0, random: 0), 2)
        XCTAssertEqual(policy.delay(afterFailures: -5, random: 0), 2)
        XCTAssertEqual(policy.delay(afterFailures: Int.max, random: 0), 60)
        for failures in [1, 3, 6, 50, 10_000] {
            for random in [0, 0.25, 0.5, 0.999, 1, 7] {
                let full = policy.delay(afterFailures: failures, random: 0)
                let wait = policy.delay(afterFailures: failures, random: random)
                XCTAssertLessThanOrEqual(wait, full)
                XCTAssertLessThanOrEqual(wait, policy.maximumDelay)
                XCTAssertGreaterThanOrEqual(wait, full * (1 - policy.jitter) - 0.000_001)
            }
        }
        XCTAssertEqual(policy.keysPageSize, 1_000, "the largest page a node serves")
    }

    // MARK: - Coordinator

    private final class StubConfigService: ConfigServiceProtocol {
        private let lock = NSLock()
        private var stored = RemoteConfig()
        private var waiting: [() -> Void] = []
        private(set) var requests = 0

        var config: RemoteConfig {
            get { lock.lock(); defer { lock.unlock() }; return stored }
            set { lock.lock(); stored = newValue; lock.unlock() }
        }

        func setupConfig(completion: @escaping () -> Void) {
            lock.lock()
            requests += 1
            waiting.append(completion)
            lock.unlock()
        }

        var requestCount: Int { lock.lock(); defer { lock.unlock() }; return requests }

        /// The remote answer arrives, with the nodes it lists.
        func answer(nodes: Set<ChainNodeModel>? = nil) {
            lock.lock()
            if let nodes { stored.defaultNodes = nodes }
            let completions = waiting
            waiting = []
            lock.unlock()
            completions.forEach { $0() }
        }
    }

    private final class Counter {
        private let lock = NSLock()
        private var count = 0
        func increment() { lock.lock(); count += 1; lock.unlock() }
        var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    }

    private func makeCoordinator(
        config: ConfigServiceProtocol,
        syncs: Counter,
        published: Loaded
    ) -> StartupNetworkCoordinator {
        StartupNetworkCoordinator(
            configService: config,
            chainConnection: { [node] in node },
            syncChains: { syncs.increment() },
            publishAssets: { published.add($0) },
            makeProvider: { [unowned self] connection in self.makeProvider(connection: connection) }
        )
    }

    func testAssetListIsLoadedOverTheRegistryConnectionAfterTheBootAndGivenToTheRegistry() {
        node.answer = healthy()
        let syncs = Counter()
        let published = Loaded()
        let coordinator = makeCoordinator(config: StubConfigService(), syncs: syncs, published: published)

        coordinator.startupDidBegin()
        settle()
        XCTAssertTrue(node.calls.isEmpty, "the chain registry is not touched before startup boots it")
        XCTAssertTrue(published.all.isEmpty)

        coordinator.chainRegistryWillBoot()
        settle()
        XCTAssertEqual(node.calls.count, 3)
        XCTAssertEqual(published.all.count, 1)
        XCTAssertEqual(published.all.first?.count, 3)
        XCTAssertEqual(syncs.value, 1, "the registry reads the new list")
        XCTAssertTrue(timers.pending.isEmpty)

        // A restart of startup in the same process keeps the list.
        coordinator.startupDidBegin()
        coordinator.chainRegistryWillBoot()
        coordinator.nodeDidConnect()
        coordinator.retryNow()
        settle()
        XCTAssertEqual(node.calls.count, 3)
        XCTAssertEqual(published.all.count, 1)
        XCTAssertEqual(syncs.value, 1)
    }

    func testAConnectedNodeAndARestartOfStartupWakeTheWaitingLoader() {
        node.answer = healthy()
        node.state = .connecting(attempt: 3)
        let syncs = Counter()
        let published = Loaded()
        let coordinator = makeCoordinator(config: StubConfigService(), syncs: syncs, published: published)
        coordinator.startupDidBegin()
        coordinator.chainRegistryWillBoot()
        settle()
        XCTAssertTrue(node.calls.isEmpty)
        XCTAssertEqual(timers.pending.count, 1)

        // "Try again" on the recovery screen, Welcome back, an account removal
        // or a node change run startup again: nothing is sent to a dead node.
        coordinator.startupDidBegin()
        settle()
        XCTAssertTrue(node.calls.isEmpty)

        node.state = .connected
        coordinator.nodeDidConnect()
        settle()
        XCTAssertEqual(node.calls.count, 3)
        XCTAssertEqual(published.all.first?.count, 3)
        XCTAssertEqual(syncs.value, 1)
    }

    func testALateRemoteConfigurationUpdatesTheRegistryOnlyAfterTheBootAndOnlyWhenTheNodesChanged() {
        let config = StubConfigService()
        let bundled = config.config.defaultNodes
        let extra = bundled.union([
            ChainNodeModel(url: URL(string: "wss://extra.invalid")!, name: "Extra", apikey: nil)
        ])
        let syncs = Counter()
        let coordinator = makeCoordinator(config: config, syncs: syncs, published: Loaded())

        coordinator.startupDidBegin()
        coordinator.startupDidBegin()
        XCTAssertEqual(config.requestCount, 1, "one request at a time")

        // Answered before the boot: the boot itself reads the configuration.
        config.answer(nodes: extra)
        XCTAssertEqual(syncs.value, 0)

        coordinator.startupDidBegin()
        XCTAssertEqual(config.requestCount, 2)
        coordinator.chainRegistryWillBoot()
        config.answer() // no answer, or the same nodes
        XCTAssertEqual(syncs.value, 0)

        coordinator.startupDidBegin()
        XCTAssertEqual(config.requestCount, 3)
        config.answer(nodes: bundled)
        XCTAssertEqual(syncs.value, 1, "a changed node list reaches the registry")
    }

    // MARK: - Startup order

    func testWalletStorageChecksStartWhileTheConfigurationAndTheAssetListArePending() {
        node.answer = { _ in .silent }
        let config = StubConfigService()
        let syncs = Counter()
        let published = Loaded()
        let coordinator = makeCoordinator(config: config, syncs: syncs, published: published)
        let settings = InMemorySettingsManager()

        let started = expectation(description: "wallet storage checks start")
        let interactor = SplashInteractor(settings: settings, network: coordinator, storageChecks: {
            started.fulfill()
        })
        interactor.setup()
        wait(for: [started], timeout: 5)

        XCTAssertEqual(config.requestCount, 1, "the remote configuration was requested")
        XCTAssertEqual(syncs.value, 0)
        XCTAssertTrue(published.all.isEmpty, "and neither it nor the asset list has arrived")
        XCTAssertEqual(settings.string(for: SettingsKey.externalGenesis.rawValue), Chain.sora.genesisHash(),
                       "the genesis is pinned locally")

        // The registry boots, the node stays silent: one request, no result,
        // and startup has long gone on.
        coordinator.chainRegistryWillBoot()
        settle()
        XCTAssertEqual(node.calls.count, 1)
        XCTAssertEqual(node.unanswered.count, 1)
        XCTAssertTrue(published.all.isEmpty)

        // Every restart of startup follows the same rule.
        let restarted = expectation(description: "wallet storage checks start again")
        let second = SplashInteractor(settings: settings, network: coordinator, storageChecks: {
            restarted.fulfill()
        })
        second.setup()
        wait(for: [restarted], timeout: 5)
        settle()
        XCTAssertEqual(config.requestCount, 1, "the pending request is not repeated")
        XCTAssertEqual(node.calls.count, 1, "and the node is not asked twice")
        withExtendedLifetime((interactor, second)) {}
    }

    // MARK: - Chain sync picks up a list that arrives during a sync

    private final class SyncObserver: EventVisitorProtocol {
        let expectation: XCTestExpectation
        init(_ expectation: XCTestExpectation) { self.expectation = expectation }
        func processChainSyncDidComplete(event _: ChainSyncDidComplete) { expectation.fulfill() }
    }

    /// The first whitelist request waits until the test lets it fail.
    private final class GatedDataFactory: DataOperationFactoryProtocol {
        let started = DispatchSemaphore(value: 0)
        private let gate = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private var isOpen = false

        func open() {
            lock.lock()
            isOpen = true
            lock.unlock()
            gate.signal()
        }

        func fetchData(from _: URL) -> BaseOperation<Data> {
            ClosureOperation { [self] in
                lock.lock()
                let isOpen = self.isOpen
                lock.unlock()
                if !isOpen {
                    started.signal()
                    gate.wait()
                }
                throw URLError(.timedOut)
            }
        }
    }

    func testAnAssetListThatArrivesDuringAChainSyncReachesTheChain() throws {
        AssetManager.networkAssets = []
        let repository = ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createRepository()
        let eventCenter = EventCenter()
        // Bootstrap pass and end of the first sync, then the same for the second.
        let finished = expectation(description: "two syncs")
        finished.expectedFulfillmentCount = 4
        let observer = SyncObserver(finished)
        eventCenter.add(observer: observer, dispatchIn: nil)
        let factory = GatedDataFactory()
        let operations = OperationQueue()
        let service = ChainSyncService(
            typesUrl: nil,
            assetsUrl: URL(string: "https://whitelist.invalid/whitelist.json"),
            dataFetchFactory: factory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: operations,
            whitelistStore: AssetWhitelistStore(directory: directory, bundledURL: R.file.whitelistJson(), logger: nil)
        )

        // Startup boots the registry before the asset list exists.
        service.syncUp()
        XCTAssertEqual(factory.started.wait(timeout: .now() + 10), .success)

        // The list arrives while that sync is still waiting for the whitelist.
        AssetManager.networkAssets = [
            AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18,
                      icon: nil, displayName: "SORA", visible: true),
            AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18,
                      icon: nil, displayName: "SORA Validator Token", visible: true)
        ]
        service.syncUp()
        factory.open()

        wait(for: [finished], timeout: 20)
        operations.waitUntilAllOperationsAreFinished()
        withExtendedLifetime(observer) {}

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operations.addOperations([fetch], waitUntilFinished: true)
        guard case let .success(chains) = fetch.result else {
            throw BaseOperationError.parentOperationCancelled
        }
        let chain = try XCTUnwrap(chains.first)
        let listed = Set(chain.assets.map { $0.assetId })
        XCTAssertEqual(listed, [WalletAssetId.xor.rawValue, WalletAssetId.val.rawValue],
                       "the request made during the sync was not lost")
    }

    // MARK: - Failing over to another node

    /// A TCP server on the loopback interface. `silent` accepts connections
    /// and never answers; `webSocket` answers the WebSocket upgrade.
    private final class LocalServer {
        enum Behaviour { case silent, webSocket }

        private let behaviour: Behaviour
        private let listener: NWListener
        private let queue = DispatchQueue(label: "StartupNetworkTests.LocalServer")
        private let lock = NSLock()
        private var connections: [NWConnection] = []
        private var upgraded: Set<ObjectIdentifier> = []
        private var closedByClient = 0

        init(_ behaviour: Behaviour) throws {
            self.behaviour = behaviour
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
            listener = try NWListener(using: parameters)
            let ready = DispatchSemaphore(value: 0)
            listener.stateUpdateHandler = { state in
                if case .ready = state { ready.signal() }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                self.lock.lock()
                self.connections.append(connection)
                self.lock.unlock()
                connection.start(queue: self.queue)
                self.receive(on: connection, buffer: Data())
            }
            listener.start(queue: queue)
            guard ready.wait(timeout: .now() + 5) == .success, listener.port != nil else {
                throw NSError(domain: "LocalServer", code: 1)
            }
        }

        var url: URL { URL(string: "ws://127.0.0.1:\(listener.port?.rawValue ?? 0)")! }
        var accepted: Int { lock.lock(); defer { lock.unlock() }; return connections.count }
        var closedByClientCount: Int { lock.lock(); defer { lock.unlock() }; return closedByClient }

        /// The server goes away: it closes every connection it holds.
        func dropConnections() {
            lock.lock()
            let all = connections
            lock.unlock()
            all.forEach { $0.cancel() }
        }

        func stop() {
            dropConnections()
            listener.cancel()
        }

        private func receive(on connection: NWConnection, buffer: Data) {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
                guard let self else { return }
                var buffer = buffer
                if let data { buffer.append(data) }
                if self.behaviour == .webSocket, buffer.range(of: Data("\r\n\r\n".utf8)) != nil {
                    self.lock.lock()
                    let isNew = self.upgraded.insert(ObjectIdentifier(connection)).inserted
                    self.lock.unlock()
                    if isNew {
                        connection.send(content: Self.upgradeAnswer(to: buffer), completion: .contentProcessed { _ in })
                    }
                    buffer = Data()
                }
                if isComplete || error != nil {
                    self.lock.lock()
                    self.closedByClient += 1
                    self.lock.unlock()
                    connection.cancel()
                    return
                }
                self.receive(on: connection, buffer: buffer)
            }
        }

        private static func upgradeAnswer(to request: Data) -> Data {
            let lines = String(decoding: request, as: UTF8.self).components(separatedBy: "\r\n")
            let key = lines.first { $0.lowercased().hasPrefix("sec-websocket-key:") }
                .map { String($0.dropFirst("sec-websocket-key:".count)).trimmingCharacters(in: .whitespaces) } ?? ""
            let digest = Insecure.SHA1.hash(data: Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))
            let accept = Data(digest).base64EncodedString()
            return Data(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n" +
                "Sec-WebSocket-Accept: \(accept)\r\n\r\n").utf8)
        }
    }

    private final class AlwaysReachable: SSFUtils.ReachabilityManagerProtocol {
        var isReachable: Bool { true }
        func add(listener _: SSFUtils.ReachabilityListenerDelegate) throws {}
        func remove(listener _: SSFUtils.ReachabilityListenerDelegate) {}
    }

    private func poll(for seconds: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() {
            if Date() > deadline { return false }
            usleep(10_000)
        }
        return true
    }

    private func isConnected(_ engine: WebSocketEngine) -> Bool {
        if case .connected = engine.state { return true }
        return false
    }

    /// The asset list is loaded over the chain registry's connection, which
    /// moves to another node when one does not work. The socket used to keep
    /// its transport for the new node: the connection to the old node stayed
    /// open, and whatever happened to it later was taken for the new node.
    func testFailingOverToAnotherNodeClosesTheOldConnectionAndIsNotDisturbedByIt() throws {
        let stalled = try LocalServer(.silent) // accepts the connection, never answers the upgrade
        let healthy = try LocalServer(.webSocket)
        defer {
            stalled.stop()
            healthy.stop()
        }
        let engine = WebSocketEngine(
            connectionName: nil,
            url: stalled.url,
            reachabilityManager: AlwaysReachable(),
            autoconnect: false,
            pingInterval: 0
        )
        engine.connectIfNeeded()
        XCTAssertTrue(poll { stalled.accepted == 1 })
        XCTAssertFalse(isConnected(engine))

        // What the chain registry does when it fails over to the next node.
        engine.disconnectIfNeeded()
        engine.reconnect(url: healthy.url)
        engine.connectIfNeeded()

        XCTAssertTrue(poll { self.isConnected(engine) }, "the next node is connected")
        XCTAssertEqual(engine.url, healthy.url)
        XCTAssertTrue(poll { stalled.closedByClientCount == 1 }, "the connection to the old node is closed")

        // The old node disappears later: that is no event of the new connection.
        stalled.dropConnections()
        usleep(500_000)
        XCTAssertTrue(isConnected(engine))
        XCTAssertEqual(healthy.accepted, 1, "one connection to the new node, and it was kept")
        XCTAssertEqual(healthy.closedByClientCount, 0)
    }

    // MARK: - A wallet that was opened without any asset list is built again

    func testOnlyAWalletBuiltWithoutAnyAssetIsBuiltAgainWhenTheListArrives() {
        let xor = AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18,
                            icon: nil, displayName: "SORA", visible: true)
        let val = AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18,
                            icon: nil, displayName: "SORA Validator Token", visible: true)
        XCTAssertTrue(AssetManager.needsWalletRebuild(shown: [], arrived: [xor, val]),
                      "the wallet was open with no asset: its screens are built again")
        XCTAssertFalse(AssetManager.needsWalletRebuild(shown: nil, arrived: [xor]),
                       "the wallet is not open yet: it will be built with the list")
        XCTAssertFalse(AssetManager.needsWalletRebuild(shown: [], arrived: []))
        XCTAssertFalse(AssetManager.needsWalletRebuild(shown: [xor], arrived: [xor, val]),
                       "a screen in use is not replaced because one asset was added")
        XCTAssertFalse(AssetManager.needsWalletRebuild(shown: [xor, val], arrived: []))
    }

    private final class StubServiceCoordinator: ServiceCoordinatorProtocol {
        func setup() {}
        func throttle() {}
        func updateOnAccountChange() {}
        func updateOnNetworkChange() {}
        func checkMigration() {}
    }

    private final class StubKeystoreImportService: KeystoreImportServiceProtocol {
        var definition: KeystoreDefinition? { nil }
        func add(observer _: KeystoreImportObserver) {}
        func remove(observer _: KeystoreImportObserver) {}
        func clear() {}
        func handle(url _: URL) -> Bool { false }
    }

    private final class TabBarOutput: MainTabBarInteractorOutputProtocol {
        let rebuilt: XCTestExpectation
        private(set) var walletTabReloads = 0
        init(rebuilt: XCTestExpectation) { self.rebuilt = rebuilt }
        func didUserChange() { rebuilt.fulfill() }
        func didReloadSelectedNetwork() { walletTabReloads += 1 }
        func didReloadSelectedAccount() {}
        func didUpdateWalletInfo() {}
        func didRequestImportAccount() {}
        func didRequestMigration(with _: MigrationServiceProtocol) {}
        func didEndMigration() {}
        func didEndTransaction() {}
        func didLanguageChange() {}
    }

    func testTheArrivalOfTheFirstAssetListRebuildsEveryTab() {
        let eventCenter = EventCenter()
        let interactor = MainTabBarInteractor(eventCenter: eventCenter,
                                              serviceCoordinator: StubServiceCoordinator(),
                                              keystoreImportService: StubKeystoreImportService())
        let rebuilt = expectation(description: "all tabs are built again")
        let output = TabBarOutput(rebuilt: rebuilt)
        interactor.presenter = output
        interactor.setup()

        eventCenter.notify(with: WalletAssetListArrived())

        wait(for: [rebuilt], timeout: 5)
        XCTAssertEqual(output.walletTabReloads, 0, "not the reload of the wallet tab alone")
        withExtendedLifetime(interactor) {}
    }
}
