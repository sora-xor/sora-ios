// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CryptoKit
import Foundation
import Network
import RobinHood
import SoraKeystore
import SSFUtils
import UIKit
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

    // MARK: - The chain registry is created on the main thread

    private final class BootLog {
        private(set) var events: [String] = []
        func add(_ event: String) { events.append(event) }
        func reset() { events = [] }
    }

    private final class RecordingNetwork: StartupNetworkCoordinating {
        let log: BootLog
        init(log: BootLog) { self.log = log }
        func startupDidBegin() { log.add("startup_began") }
        func chainRegistryWillBoot() { log.add("background_work_told") }
    }

    private final class RecordingRegistry: ChainRegistryProtocol {
        let log: BootLog
        init(log: BootLog) { self.log = log }
        var availableChainIds: Set<ChainModel.Id>? { nil }
        func getConnection(for _: ChainModel.Id) -> ChainConnection? { nil }
        func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? { nil }
        func getAssetManager(for _: ChainModel.Id) -> AssetManagerProtocol { fatalError("not used") }
        func getChain(for _: ChainModel.Id) -> ChainModel? { nil }
        func getActiveNode(for _: ChainModel.Id) -> ChainNodeModel? { nil }
        func subscribeToChians() {}
        func chainsSubscribe(_: AnyObject, runningInQueue _: DispatchQueue,
                             updateClosure _: @escaping ([DataProviderChange<ChainModel>]) -> Void) {}
        func chainsUnsubscribe(_: AnyObject) {}
        func performHotBoot() { log.add("hot_boot") }
        func performColdBoot() { log.add("cold_boot") }
        func syncUp() {}
    }

    /// Creating the registry reads the app's window, which only the main
    /// thread may do. The asset loader uses the registry from its own queue
    /// as soon as it hears of the boot, and it used to hear of it one
    /// statement before the main thread first touched the registry: the
    /// loader's queue could be the one that created it.
    func testTheChainRegistryIsCreatedOnTheMainThreadBeforeTheBackgroundWorkHearsOfTheBoot() {
        let log = BootLog()
        let network = RecordingNetwork(log: log)
        let registry = RecordingRegistry(log: log)
        let create: () -> ChainRegistryProtocol = {
            XCTAssertTrue(Thread.isMainThread)
            log.add("registry_created")
            return registry
        }

        SplashInteractor.bootChainRegistry(hasSelectedAccount: true, network: network, registry: create)
        XCTAssertEqual(log.events, ["registry_created", "background_work_told", "hot_boot"])

        log.reset()
        SplashInteractor.bootChainRegistry(hasSelectedAccount: false, network: network, registry: create)
        XCTAssertEqual(log.events, ["registry_created", "background_work_told", "cold_boot"])
    }

    // MARK: - The loader's limits keep their length

    func testTheLoadersTimersFireOnItsOwnQueueAndCanBeCancelled() {
        let key = DispatchSpecificKey<String>()
        let own = DispatchQueue(label: "StartupNetworkTests.timer")
        own.setSpecific(key: key, value: "own")
        let timer = AssetsInfoProvider.timer(on: own)

        let fired = expectation(description: "the timer fired")
        let cancel = timer(0.05) {
            XCTAssertEqual(DispatchQueue.getSpecific(key: key), "own")
            fired.fulfill()
        }
        wait(for: [fired], timeout: 5)
        cancel()

        let cancelled = expectation(description: "a cancelled timer does not fire")
        cancelled.isInverted = true
        let cancelSecond = timer(0.05) { cancelled.fulfill() }
        cancelSecond()
        wait(for: [cancelled], timeout: 0.4)
    }

    /// A wallet that opens on a slow node puts many blocking requests on the
    /// shared queues, which have a limited number of threads for the whole
    /// app. The loader's timers used to fire on the shared utility queue: in
    /// a run on the simulator a 20 s timeout fired after 47 s. With the
    /// app's own timer (none is given here) the timeout and the wait before
    /// the next attempt keep their length while every shared thread is taken.
    func testTimeoutAndRetryKeepTheirLengthWhileTheSharedQueuesAreBlocked() {
        let release = DispatchSemaphore(value: 0)
        let blocked = 256
        for _ in 0 ..< blocked {
            DispatchQueue.global(qos: .utility).async { release.wait() }
        }
        defer {
            for _ in 0 ..< blocked { release.signal() }
        }
        // Let the shared pool fill up.
        usleep(300_000)

        // The first request is never answered; after that the node is healthy.
        let healthy = self.healthy()
        node.answer = { call in call.id == 1 ? .silent : healthy(call) }
        var policy = self.policy()
        policy.keysPageTimeout = 0.3
        policy.initialDelay = 0.2
        let loaded = expectation(description: "the list arrives")
        let provider = AssetsInfoProvider(
            connection: { [node] in node },
            storageKeyFactory: StorageKeyFactory(),
            chainId: { "chain" },
            policy: policy,
            random: { 0 },
            logger: nil
        )
        let start = Date()
        provider.load { _ in loaded.fulfill() }
        wait(for: [loaded], timeout: 10)

        XCTAssertLessThan(Date().timeIntervalSince(start), 5, "0.3 s timeout and 0.2 s wait, not the length of the blockage")
        XCTAssertEqual(node.cancelled, [1], "the request that timed out was taken off the node")
        XCTAssertEqual(node.calls.count, 4, "one silent request, then the two key pages and the values")
        withExtendedLifetime(provider) {}
    }

    // MARK: - The node outage status

    /// When every node has failed once, a status at the top of the screen says
    /// that the network is unavailable. Only a change of the device's
    /// reachability took it down, so after a node outage or a captive network
    /// it stayed over a wallet that was connected again. The registry now
    /// takes it down when `connected()` says that it was shown.
    func testANodeThatConnectsTakesTheOutageStatusDownOnce() {
        let nodes = [
            ChainNodeModel(url: URL(string: "wss://one.invalid")!, name: "One", apikey: nil),
            ChainNodeModel(url: URL(string: "wss://two.invalid")!, name: "Two", apikey: nil)
        ]
        var failover = NodeConnectionFailover()
        XCTAssertFalse(failover.connected(), "nothing was shown")

        XCTAssertFalse(failover.failed(url: nodes[0].url, candidates: nodes).shouldPresentUnavailable)
        XCTAssertFalse(failover.connected(), "one node failed and the next connected: nothing was shown")

        XCTAssertFalse(failover.failed(url: nodes[0].url, candidates: nodes).shouldPresentUnavailable)
        XCTAssertTrue(failover.failed(url: nodes[1].url, candidates: nodes).shouldPresentUnavailable)
        XCTAssertFalse(failover.failed(url: nodes[0].url, candidates: nodes).shouldPresentUnavailable)
        XCTAssertTrue(failover.connected(), "the status was shown: it is taken down")
        XCTAssertFalse(failover.connected(), "once")

        // The next outage shows it again, and the next connection takes it down again.
        XCTAssertFalse(failover.failed(url: nodes[0].url, candidates: nodes).shouldPresentUnavailable)
        XCTAssertTrue(failover.failed(url: nodes[1].url, candidates: nodes).shouldPresentUnavailable)
        XCTAssertTrue(failover.connected())
    }

    // MARK: - Chain sync picks up a list that arrives during a sync

    /// The first whitelist request waits until the test lets it end, with a
    /// failure or with the list the test gives it.
    private final class GatedDataFactory: DataOperationFactoryProtocol {
        let started = DispatchSemaphore(value: 0)
        private let gate = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private var isOpen = false
        private var answer: Data?

        func open(with data: Data? = nil) {
            lock.lock()
            isOpen = true
            answer = data
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
                lock.lock()
                let answer = self.answer
                lock.unlock()
                guard let answer else { throw URLError(.timedOut) }
                return answer
            }
        }
    }

    /// A chain store in memory. One save, chosen by the test, waits until the
    /// test lets it go on: the pass it belongs to has then read everything
    /// and written nothing.
    private final class GatedChainRepository: DataProviderRepositoryProtocol {
        typealias Model = ChainModel

        let heldSaveStarted = DispatchSemaphore(value: 0)
        private let gate = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private var stored: [ChainModel] = []
        private var saves = 0
        private let heldSave: Int

        /// - Parameter heldSave: the number (1 for the first) of the save to hold.
        init(holdingSave heldSave: Int) { self.heldSave = heldSave }

        var snapshot: [ChainModel] { lock.lock(); defer { lock.unlock() }; return stored }
        var listedAssetIds: Set<String> { Set(snapshot.first?.assets.map { $0.assetId } ?? []) }
        func releaseHeldSave() { gate.signal() }

        func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[ChainModel]> {
            ClosureOperation { self.snapshot }
        }

        func saveOperation(_ updates: @escaping () throws -> [ChainModel],
                           _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> {
            ClosureOperation { [self] in
                let changed = try updates()
                let removed = try deletions()
                lock.lock()
                saves += 1
                let number = saves
                lock.unlock()
                if number == heldSave {
                    heldSaveStarted.signal()
                    gate.wait()
                }
                lock.lock()
                defer { lock.unlock() }
                stored.removeAll { old in
                    removed.contains(old.chainId) || changed.contains { $0.chainId == old.chainId }
                }
                stored.append(contentsOf: changed)
            }
        }

        func saveBatchOperation(_ updates: @escaping () throws -> [ChainModel],
                                _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> {
            saveOperation(updates, deletions)
        }

        func fetchOperation(by ids: @escaping () throws -> [String],
                            options _: RepositoryFetchOptions) -> BaseOperation<[ChainModel]> {
            ClosureOperation { let selected = try ids(); return self.snapshot.filter { selected.contains($0.chainId) } }
        }

        func fetchOperation(by id: @escaping () throws -> String,
                            options _: RepositoryFetchOptions) -> BaseOperation<ChainModel?> {
            ClosureOperation { let selected = try id(); return self.snapshot.first { $0.chainId == selected } }
        }

        func fetchOperation(by _: RepositorySliceRequest,
                            options: RepositoryFetchOptions) -> BaseOperation<[ChainModel]> {
            fetchAllOperation(with: options)
        }

        func replaceOperation(_ models: @escaping () throws -> [ChainModel]) -> BaseOperation<Void> {
            saveOperation(models, { self.snapshot.map(\.chainId) })
        }

        func deleteAllOperation() -> BaseOperation<Void> { replaceOperation { [] } }
        func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { self.snapshot.count } }
    }

    /// Gives the chain sync the whitelists the test chooses.
    private final class StubWhitelistStore: AssetWhitelistStoring {
        let lastGood: AssetWhitelist
        let remote: AssetWhitelist
        init(lastGood: AssetWhitelist, remote: AssetWhitelist) {
            self.lastGood = lastGood
            self.remote = remote
        }
        func current() -> AssetWhitelist { lastGood }
        func acceptRemote(_: Data) -> AssetWhitelist? { remote }
    }

    private var xorAndVal: [AssetInfo] {
        [
            AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18,
                      icon: nil, displayName: "SORA", visible: true),
            AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18,
                      icon: nil, displayName: "SORA Validator Token", visible: true)
        ]
    }

    private func whitelist(admitting ids: [String], source: AssetWhitelist.Source) throws -> AssetWhitelist {
        let entries: [[String: Any]] = ids.map {
            ["address": $0, "symbol": "S", "name": "N", "decimals": 18, "icon": "icon"]
        }
        let data = try JSONSerialization.data(withJSONObject: entries)
        return try XCTUnwrap(AssetWhitelist.decode(data, source: source))
    }

    private func storedAssetIds(in repository: CoreDataRepository<ChainModel, CDChain>) -> Set<String> {
        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([fetch], waitUntilFinished: true)
        guard case let .success(chains) = fetch.result else { return [] }
        return Set(chains.first?.assets.map { $0.assetId } ?? [])
    }

    /// The whitelist is fetched over HTTP after the chain has been saved, and
    /// that request can take as long as its timeout on a slow or filtered
    /// network. An asset list that arrives meanwhile used to wait for it.
    func testAnAssetListThatArrivesDuringTheWhitelistRequestReachesTheChainAtOnce() throws {
        AssetManager.networkAssets = []
        let repository = ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createRepository()
        let factory = GatedDataFactory()
        let operations = OperationQueue()
        let service = ChainSyncService(
            typesUrl: nil,
            assetsUrl: URL(string: "https://whitelist.invalid/whitelist.json"),
            dataFetchFactory: factory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: EventCenter(),
            operationQueue: operations,
            whitelistStore: AssetWhitelistStore(directory: directory, bundledURL: R.file.whitelistJson(), logger: nil)
        )
        defer { factory.open() }

        // Startup boots the registry before the asset list exists.
        service.syncUp()
        XCTAssertEqual(factory.started.wait(timeout: .now() + 10), .success)
        XCTAssertTrue(storedAssetIds(in: repository).isEmpty)

        // The list arrives while that sync is still waiting for the whitelist.
        AssetManager.networkAssets = xorAndVal
        service.syncUp()

        let expected: Set<String> = [WalletAssetId.xor.rawValue, WalletAssetId.val.rawValue]
        XCTAssertTrue(poll(for: 10) { self.storedAssetIds(in: repository) == expected },
                      "the list is saved while the whitelist request is still running")
        XCTAssertTrue(service.isSyncing, "and that request has not ended")

        // The whitelist request fails at last: the sync ends, the list stays.
        factory.open()
        XCTAssertTrue(poll(for: 10) { !service.isSyncing })
        operations.waitUntilAllOperationsAreFinished()
        XCTAssertEqual(storedAssetIds(in: repository), expected)
    }

    /// A request made while the first pass is running (it has read the old
    /// value) is served as soon as that pass has saved, not after the
    /// whitelist request.
    func testAnAssetListThatArrivesDuringTheFirstPassIsSavedBeforeTheWhitelistAnswers() throws {
        AssetManager.networkAssets = []
        let repository = GatedChainRepository(holdingSave: 1)
        let factory = GatedDataFactory()
        let operations = OperationQueue()
        let service = ChainSyncService(
            typesUrl: nil,
            assetsUrl: URL(string: "https://whitelist.invalid/whitelist.json"),
            dataFetchFactory: factory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: EventCenter(),
            operationQueue: operations,
            whitelistStore: AssetWhitelistStore(directory: directory, bundledURL: R.file.whitelistJson(), logger: nil)
        )
        defer {
            repository.releaseHeldSave()
            factory.open()
        }

        service.syncUp()
        // The first pass has read an empty list and is about to save.
        XCTAssertEqual(repository.heldSaveStarted.wait(timeout: .now() + 10), .success)
        AssetManager.networkAssets = xorAndVal
        service.syncUp()
        repository.releaseHeldSave()

        let expected: Set<String> = [WalletAssetId.xor.rawValue, WalletAssetId.val.rawValue]
        XCTAssertTrue(poll(for: 10) { repository.listedAssetIds == expected },
                      "the request made during the first pass is served")
        XCTAssertEqual(factory.started.wait(timeout: .now() + 10), .success)
        XCTAssertTrue(service.isSyncing, "while the whitelist request is still running")

        factory.open()
        XCTAssertTrue(poll(for: 10) { !service.isSyncing })
        operations.waitUntilAllOperationsAreFinished()
        XCTAssertEqual(repository.listedAssetIds, expected)
    }

    /// The pass that saves a new value during the whitelist request and the
    /// pass that applies the whitelist both read the stored chain and save
    /// what they made of it. They run one after the other: the older answer
    /// (made with the last good whitelist) is never saved over the newer one.
    func testAPassDuringTheWhitelistRequestNeverOverwritesThePassWithTheNewWhitelist() throws {
        AssetManager.networkAssets = []
        let xor = WalletAssetId.xor.rawValue
        let val = WalletAssetId.val.rawValue
        // The last good whitelist does not list VAL yet; the new one does.
        let store = StubWhitelistStore(
            lastGood: try whitelist(admitting: [xor], source: .lastKnownGood),
            remote: try whitelist(admitting: [xor, val], source: .remote)
        )
        let repository = GatedChainRepository(holdingSave: 2)
        let factory = GatedDataFactory()
        let operations = OperationQueue()
        let service = ChainSyncService(
            typesUrl: nil,
            assetsUrl: URL(string: "https://whitelist.invalid/whitelist.json"),
            dataFetchFactory: factory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: EventCenter(),
            operationQueue: operations,
            whitelistStore: store
        )
        defer {
            repository.releaseHeldSave()
            factory.open()
        }

        service.syncUp()
        XCTAssertEqual(factory.started.wait(timeout: .now() + 10), .success)

        // The asset list arrives: its pass has read the last good whitelist
        // and is held just before it saves.
        AssetManager.networkAssets = xorAndVal
        service.syncUp()
        XCTAssertEqual(repository.heldSaveStarted.wait(timeout: .now() + 10), .success)

        // The whitelist request answers now. Its pass must wait.
        factory.open(with: Data("[]".utf8))
        usleep(700_000)
        XCTAssertTrue(repository.listedAssetIds.isEmpty, "nothing was saved around the held pass")
        XCTAssertTrue(service.isSyncing)

        repository.releaseHeldSave()
        XCTAssertTrue(poll(for: 10) { !service.isSyncing })
        operations.waitUntilAllOperationsAreFinished()
        XCTAssertEqual(repository.listedAssetIds, [xor, val],
                       "the chain ends with the answer made with the new whitelist")
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
        private(set) var assetListChecks = 0
        private(set) var accountRebuilds = 0
        private(set) var walletTabReloads = 0
        var onAssetListCheck: (() -> Void)?
        func didReceiveWalletAssetList() {
            assetListChecks += 1
            onAssetListCheck?()
        }
        func didUserChange() { accountRebuilds += 1 }
        func didReloadSelectedNetwork() { walletTabReloads += 1 }
        func didReloadSelectedAccount() {}
        func didUpdateWalletInfo() {}
        func didRequestImportAccount() {}
        func didRequestMigration(with _: MigrationServiceProtocol) {}
        func didEndMigration() {}
        func didEndTransaction() {}
        func didLanguageChange() {}
    }

    /// `WalletAssetListArrived` is posted once. The tab bar starts listening
    /// when it has appeared (`setup`), so a list that arrived after the tabs
    /// were built and before that was announced to nobody. `setup` now asks.
    func testTheTabBarLooksForTheAssetListWhenItStartsListeningAndOnTheEvent() {
        let eventCenter = EventCenter()
        let interactor = MainTabBarInteractor(eventCenter: eventCenter,
                                              serviceCoordinator: StubServiceCoordinator(),
                                              keystoreImportService: StubKeystoreImportService())
        let output = TabBarOutput()
        interactor.presenter = output

        // Posted before anyone listens: lost.
        let lost = expectation(description: "the early event was delivered to nobody")
        eventCenter.notify(with: WalletAssetListArrived()) { lost.fulfill() }
        wait(for: [lost], timeout: 5)
        XCTAssertEqual(output.assetListChecks, 0)

        interactor.setup()
        XCTAssertEqual(output.assetListChecks, 1, "the tab bar looks for itself when it starts listening")

        let checked = expectation(description: "the event leads to the same check")
        output.onAssetListCheck = { checked.fulfill() }
        eventCenter.notify(with: WalletAssetListArrived())
        wait(for: [checked], timeout: 5)
        XCTAssertEqual(output.assetListChecks, 2)
        XCTAssertEqual(output.accountRebuilds, 0, "not the unconditional rebuild of an account switch")
        XCTAssertEqual(output.walletTabReloads, 0, "and not the reload of the wallet tab alone")
        withExtendedLifetime(interactor) {}
    }

    private final class RecordingWireframe: MainTabBarWireframeProtocol {
        var walletContext: CommonWalletContextProtocol {
            get { fatalError("not used") }
            set {}
        }
        private(set) var calls: [String] = []
        func showNewWalletView(on _: MainTabBarViewProtocol?) { calls.append("reload_wallet_tab") }
        func reloadWalletContent() { calls.append("reload_content") }
        func presentAccountImport(on _: MainTabBarViewProtocol?) {}
        func presentClaim(on _: MainTabBarViewProtocol?, with _: MigrationServiceProtocol) {}
        func removeClaim(on _: MainTabBarViewProtocol?) {}
        func showTransactionSuccess(on _: MainTabBarViewProtocol?) {}
        func recreateWalletViewController(on _: MainTabBarViewProtocol?) { calls.append("rebuild_all") }
        func rebuildWalletForArrivedAssetListIfNeeded(on _: MainTabBarViewProtocol?) { calls.append("asset_list_check") }
    }

    /// The reload of the wallet tab alone (a node change) reads the asset
    /// list again, after which the manager posts no event for a first list.
    /// The other tabs would stay as they were built, so the check follows.
    func testEveryReloadOfTheWalletIsFollowedByTheAssetListCheck() {
        let presenter = MainTabBarPresenter()
        let wireframe = RecordingWireframe()
        presenter.wireframe = wireframe

        presenter.didReceiveWalletAssetList()
        XCTAssertEqual(wireframe.calls, ["asset_list_check"],
                       "the first list goes through the check, never straight to a rebuild")
        presenter.didReloadSelectedNetwork()
        XCTAssertEqual(wireframe.calls.suffix(2), ["reload_wallet_tab", "asset_list_check"])
        presenter.didUpdateWalletInfo()
        XCTAssertEqual(wireframe.calls.suffix(2), ["reload_content", "asset_list_check"])
    }

    // MARK: - The rebuild takes no screen away from the user

    /// Timers of `WalletAssetListRebuild`, fired by the test.
    private final class ManualSchedule {
        private var entries: [(delay: TimeInterval, fire: () -> Void, isDone: Bool)] = []

        var schedule: WalletAssetListRebuild.Scheduler {
            { [self] delay, fire in
                let index = entries.count
                entries.append((delay, fire, false))
                return { [self] in entries[index].isDone = true }
            }
        }

        var pending: [TimeInterval] { entries.filter { !$0.isDone }.map(\.delay) }

        func fireNext() {
            guard let index = entries.firstIndex(where: { !$0.isDone }) else { return }
            entries[index].isDone = true
            entries[index].fire()
        }
    }

    /// The wallet as the rebuild sees it.
    private final class WalletStandIn {
        var assets: [AssetInfo]? = []
        var canReplaceTabs = true
        var rebuildWorks = true
        private(set) var rebuilds = 0
        weak var rebuild: WalletAssetListRebuild?

        func check() {
            rebuild?.rebuildIfNeeded(
                currentAssets: { [unowned self] in self.assets },
                canReplaceTabs: { [unowned self] in self.canReplaceTabs },
                rebuild: { [unowned self] in
                    self.rebuilds += 1
                    if self.rebuildWorks { self.rebuild?.tabsWereBuilt(from: self.assets ?? []) }
                }
            )
        }
    }

    func testTabsBuiltWithoutAssetsAreBuiltAgainOnceWhenTheListIsThere() {
        let schedule = ManualSchedule()
        let rebuild = WalletAssetListRebuild(isBuiltWithoutAssets: true, schedule: schedule.schedule)
        let wallet = WalletStandIn()
        wallet.rebuild = rebuild

        // The check made when the tab bar appears, before any list: nothing.
        wallet.check()
        XCTAssertEqual(wallet.rebuilds, 0)
        XCTAssertTrue(schedule.pending.isEmpty, "nothing waits and nothing polls while there is no list")

        // The list arrived without an event that anyone heard. The next check
        // (the tab bar appears, the wallet reloads) finds it.
        wallet.assets = xorAndVal
        wallet.check()
        XCTAssertEqual(wallet.rebuilds, 1)
        XCTAssertFalse(rebuild.isBuiltWithoutAssets)

        // The event, or any later check, does not build them a second time.
        wallet.check()
        wallet.check()
        XCTAssertEqual(wallet.rebuilds, 1)
        XCTAssertTrue(schedule.pending.isEmpty)
    }

    func testTabsBuiltFromAListAreNeverReplacedByAnAssetListCheck() {
        let schedule = ManualSchedule()
        let rebuild = WalletAssetListRebuild(isBuiltWithoutAssets: false, schedule: schedule.schedule)
        let wallet = WalletStandIn()
        wallet.rebuild = rebuild
        wallet.assets = xorAndVal
        wallet.check()
        XCTAssertEqual(wallet.rebuilds, 0, "a screen in use is not replaced because the list changed")
        XCTAssertTrue(schedule.pending.isEmpty)
    }

    /// The user opened More and is reading a recovery phrase, or is in the
    /// node list, when the list arrives. Replacing the tabs then would close
    /// that screen without a word.
    func testTheRebuildWaitsUntilNoScreenWouldBeTakenAway() {
        let schedule = ManualSchedule()
        let rebuild = WalletAssetListRebuild(isBuiltWithoutAssets: true, schedule: schedule.schedule)
        let wallet = WalletStandIn()
        wallet.rebuild = rebuild
        wallet.assets = xorAndVal
        wallet.canReplaceTabs = false

        wallet.check()
        XCTAssertEqual(wallet.rebuilds, 0, "the screen the user is on stays")
        XCTAssertTrue(rebuild.isWaiting)
        XCTAssertEqual(schedule.pending, [WalletAssetListRebuild.recheckInterval], "it looks again in a second")

        // Still there a second later, and the second after that.
        schedule.fireNext()
        schedule.fireNext()
        XCTAssertEqual(wallet.rebuilds, 0)
        XCTAssertEqual(schedule.pending.count, 1, "one timer at a time")

        // Another check while it waits (the event, a balance update) does not
        // add a second timer.
        wallet.check()
        XCTAssertEqual(schedule.pending.count, 1)

        // The user is back at the first screen of the tab.
        wallet.canReplaceTabs = true
        schedule.fireNext()
        XCTAssertEqual(wallet.rebuilds, 1)
        XCTAssertFalse(rebuild.isWaiting)
        XCTAssertTrue(schedule.pending.isEmpty, "and nothing polls any more")
    }

    func testAnAccountSwitchWhileTheRebuildWaitsEndsTheWait() {
        let schedule = ManualSchedule()
        let rebuild = WalletAssetListRebuild(isBuiltWithoutAssets: true, schedule: schedule.schedule)
        let wallet = WalletStandIn()
        wallet.rebuild = rebuild
        wallet.assets = xorAndVal
        wallet.canReplaceTabs = false
        wallet.check()
        XCTAssertTrue(rebuild.isWaiting)

        // The tabs are built for the other account, from the list.
        rebuild.tabsWereBuilt(from: xorAndVal)
        XCTAssertFalse(rebuild.isWaiting)
        XCTAssertTrue(schedule.pending.isEmpty)
        wallet.canReplaceTabs = true
        wallet.check()
        XCTAssertEqual(wallet.rebuilds, 0)
    }

    func testARebuildThatDoesNotWorkIsTriedAFewTimesAndThenLeftAlone() {
        let schedule = ManualSchedule()
        let rebuild = WalletAssetListRebuild(isBuiltWithoutAssets: true, schedule: schedule.schedule)
        let wallet = WalletStandIn()
        wallet.rebuild = rebuild
        wallet.assets = xorAndVal
        wallet.rebuildWorks = false

        wallet.check()
        for _ in 0 ..< 10 { schedule.fireNext() }
        XCTAssertEqual(wallet.rebuilds, WalletAssetListRebuild.maximumFailedRebuilds)
        XCTAssertTrue(schedule.pending.isEmpty, "no endless loop of rebuilds")
        XCTAssertTrue(rebuild.isBuiltWithoutAssets, "the next check may still build them")
    }

    func testTheWaitEndsWithItsOwner() {
        let schedule = ManualSchedule()
        var rebuild: WalletAssetListRebuild? = WalletAssetListRebuild(isBuiltWithoutAssets: true,
                                                                     schedule: schedule.schedule)
        let wallet = WalletStandIn()
        wallet.rebuild = rebuild
        wallet.assets = xorAndVal
        wallet.canReplaceTabs = false
        wallet.check()
        XCTAssertEqual(schedule.pending.count, 1)
        rebuild = nil
        XCTAssertTrue(schedule.pending.isEmpty, "the wallet was closed: its timer is cancelled")
    }

    @MainActor
    func testTabsAreReplacedOnlyWhileEveryTabShowsItsFirstScreenAndNothingIsPresented() {
        let tabs = UITabBarController()
        let wallet = UINavigationController(rootViewController: UIViewController())
        let more = UINavigationController(rootViewController: UIViewController())
        tabs.viewControllers = [wallet, UIViewController(), more]
        let window = UIWindow.makeSoraSceneWindow()
        window.rootViewController = tabs
        window.isHidden = false
        defer {
            tabs.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }
        // UIKit ends a transition, also one without animation, on a later
        // turn of the run loop. The rebuild then simply looks again.
        func becomesReplaceable() -> Bool {
            let deadline = Date().addingTimeInterval(3)
            while !WalletAssetListRebuild.canReplaceTabs(of: tabs), Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            }
            return WalletAssetListRebuild.canReplaceTabs(of: tabs)
        }
        XCTAssertTrue(becomesReplaceable())

        // A screen pushed on a tab, also on one that is not selected.
        more.pushViewController(UIViewController(), animated: false)
        XCTAssertFalse(WalletAssetListRebuild.canReplaceTabs(of: tabs))
        more.popViewController(animated: false)
        XCTAssertTrue(becomesReplaceable())

        // A screen presented over the tabs, from the tab bar or from a tab.
        tabs.present(UIViewController(), animated: false)
        XCTAssertFalse(WalletAssetListRebuild.canReplaceTabs(of: tabs))
        tabs.dismiss(animated: false)
        XCTAssertTrue(becomesReplaceable())
        wallet.present(UIViewController(), animated: false)
        XCTAssertFalse(WalletAssetListRebuild.canReplaceTabs(of: tabs))
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        XCTAssertFalse(WalletAssetListRebuild.canReplaceTabs(of: tabs), "and it stays so while the screen is up")
    }

    func testTheRebuildTimerRunsOnTheMainRunLoop() {
        let fired = expectation(description: "the timer fired")
        let cancel = WalletAssetListRebuild.mainRunLoopTimer(0.05) {
            XCTAssertTrue(Thread.isMainThread)
            fired.fulfill()
        }
        wait(for: [fired], timeout: 5)
        cancel()

        let cancelled = expectation(description: "a cancelled timer does not fire")
        cancelled.isInverted = true
        let cancelSecond = WalletAssetListRebuild.mainRunLoopTimer(0.05) { cancelled.fulfill() }
        cancelSecond()
        wait(for: [cancelled], timeout: 0.4)
    }

    // MARK: - The asset manager announces the first list

    private final class ArrivalObserver: EventVisitorProtocol {
        private let lock = NSLock()
        private var count = 0
        var arrivals: Int { lock.lock(); defer { lock.unlock() }; return count }
        func processWalletAssetListArrived(event _: WalletAssetListArrived) {
            lock.lock()
            count += 1
            lock.unlock()
        }
    }

    /// The production wiring behind `WalletAssetListArrived`: a real
    /// `AssetManager` on a chain store in memory. The wallet is set up while
    /// the chain has no asset; the chain sync then saves the chain with the
    /// list. One event is posted, and none when the list of a wallet that
    /// already shows assets changes.
    func testTheAssetManagerAnnouncesTheFirstListOfAWalletSetUpWithoutAssetsAndOnlyThat() throws {
        let facade = SubstrateStorageTestFacade()
        let repository = ChainRepositoryFactory(storageFacade: facade).createRepository()
        let observable = CoreDataContextObservable(
            service: facade.databaseService,
            mapper: repository.dataMapper,
            predicate: { _ in true }
        )
        observable.start { XCTAssertNil($0) }
        let operations = OperationQueue()
        let provider = StreamableProvider(
            source: AnyStreamableSource(SoraPassport.EmptyStreamableSource<ChainModel>()),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operations)
        )
        let eventCenter = EventCenter()
        let observer = ArrivalObserver()
        eventCenter.add(observer: observer, dispatchIn: nil)
        let chainId = "0x" + String(repeating: "7a", count: 32)
        let assetStorage: CoreDataRepository<AssetInfo, CDAssetInfo> = facade.createRepository()
        let manager = AssetManager(
            storage: AnyDataProviderRepository(assetStorage),
            chainProvider: provider,
            chainId: chainId,
            operationManager: OperationManager(operationQueue: operations),
            eventCenter: eventCenter
        )
        let pswap = AssetInfo(id: WalletAssetId.pswap.rawValue, symbol: "PSWAP", chainId: "", precision: 18,
                              icon: nil, displayName: "Polkaswap", visible: true)
        let node = ChainNodeModel(url: URL(string: "wss://node.invalid")!, name: "Node", apikey: nil)

        // What the chain sync saves: the chain made of the list it has.
        func save(_ assets: [AssetInfo]) throws {
            let chain = ChainSyncService.preparedChain(
                chainId: chainId, addressPrefix: 69, name: "SORA", nodes: [node], typesURL: nil,
                local: nil, assets: assets, whitelist: .empty
            )
            XCTAssertEqual(chain.assets.count, assets.count)
            let operation = repository.saveOperation({ [chain] }, { [] })
            operations.addOperations([operation], waitUntilFinished: true)
            guard case .success = operation.result else {
                throw BaseOperationError.parentOperationCancelled
            }
        }
        func flushEvents() {
            let flushed = expectation(description: "events delivered")
            eventCenter.notify(with: ChainSyncDidStart()) { flushed.fulfill() }
            wait(for: [flushed], timeout: 10)
        }
        func waitForAssets(_ count: Int) {
            let deadline = Date().addingTimeInterval(10)
            while manager.getAssetList()?.count != count, Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            }
            XCTAssertEqual(manager.getAssetList()?.count, count)
        }

        // A first launch: the chain is saved before any list exists, and the
        // wallet is opened.
        try save([])
        manager.setup(for: SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(),
                                                  operationQueue: OperationQueue()))
        XCTAssertEqual(manager.getAssetList()?.isEmpty, true, "the wallet shows no asset")
        flushEvents()
        XCTAssertEqual(observer.arrivals, 0)

        // The list arrives and the chain sync saves it.
        //
        // The manager starts to listen in the background (RobinHood registers
        // an observer after a fetch of its own), and a save made before it
        // listens is not announced to it. On a busy machine that took longer
        // than the two saves above. So the list is saved, in two alternating
        // forms, until the manager shows it: from then on it listens.
        var arriving = xorAndVal
        let listening = Date().addingTimeInterval(30)
        while manager.getAssetList()?.isEmpty != false, Date() < listening {
            try save(arriving)
            arriving = arriving.count == 2 ? [xorAndVal[0]] : xorAndVal
            let nextSave = Date().addingTimeInterval(0.5)
            while manager.getAssetList()?.isEmpty != false, Date() < nextSave {
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            }
        }
        XCTAssertEqual(manager.getAssetList()?.isEmpty, false, "the wallet has its first list")
        flushEvents()
        XCTAssertEqual(observer.arrivals, 1, "the first list of a wallet that showed no asset is announced")

        // A later change of a list that is shown is not announced: the
        // screens in use are not replaced for it.
        try save(xorAndVal + [pswap])
        waitForAssets(3)
        flushEvents()
        XCTAssertEqual(observer.arrivals, 1, "one event, for the first list only")
        withExtendedLifetime((manager, observer, provider)) {}
    }

    // MARK: - A wallet built without an asset list leaves the saved balances alone

    /// The balance cache in memory: one entry per account, shared by every
    /// balance provider of that account, as in the app.
    private final class BalanceCache: DataProviderRepositoryProtocol {
        typealias Model = SingleValueProviderObject

        private let lock = NSLock()
        private var stored: [String: SingleValueProviderObject] = [:]

        var all: [SingleValueProviderObject] { lock.lock(); defer { lock.unlock() }; return Array(stored.values) }

        func balances(of account: String) -> [BalanceData]? {
            all.first { $0.identifier == account }.flatMap { try? JSONDecoder().decode([BalanceData].self, from: $0.payload) }
        }

        func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[SingleValueProviderObject]> {
            ClosureOperation { self.all }
        }

        func saveOperation(_ updates: @escaping () throws -> [SingleValueProviderObject],
                           _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> {
            ClosureOperation { [self] in
                let changed = try updates()
                let removed = try deletions()
                lock.lock()
                defer { lock.unlock() }
                removed.forEach { stored[$0] = nil }
                changed.forEach { stored[$0.identifier] = $0 }
            }
        }

        func saveBatchOperation(_ updates: @escaping () throws -> [SingleValueProviderObject],
                                _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> {
            saveOperation(updates, deletions)
        }

        func fetchOperation(by ids: @escaping () throws -> [String],
                            options _: RepositoryFetchOptions) -> BaseOperation<[SingleValueProviderObject]> {
            ClosureOperation { let selected = try ids(); return self.all.filter { selected.contains($0.identifier) } }
        }

        func fetchOperation(by id: @escaping () throws -> String,
                            options _: RepositoryFetchOptions) -> BaseOperation<SingleValueProviderObject?> {
            ClosureOperation { let selected = try id(); return self.all.first { $0.identifier == selected } }
        }

        func fetchOperation(by _: RepositorySliceRequest,
                            options: RepositoryFetchOptions) -> BaseOperation<[SingleValueProviderObject]> {
            fetchAllOperation(with: options)
        }

        func replaceOperation(_ models: @escaping () throws -> [SingleValueProviderObject]) -> BaseOperation<Void> {
            saveOperation(models, { self.all.map(\.identifier) })
        }

        func deleteAllOperation() -> BaseOperation<Void> { replaceOperation { [] } }
        func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { self.all.count } }
    }

    /// Waits on the main run loop: the asset provider takes its balances there.
    private func waitOnMain(for seconds: TimeInterval = 10, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        return condition()
    }

    /// Startup does not wait for the asset list, so the wallet's tabs can be
    /// built without one and are built again when it arrives. The provider of
    /// the tabs without a list used to load "no balances" and save that over
    /// the account's cached balances, which every provider of the account
    /// shares. On the simulator the tabs that were built again then showed
    /// an empty asset card until the next launch.
    func testAWalletBuiltWithoutAnAssetListNeitherLoadsNorOverwritesTheSavedBalances() {
        let account = "balances-of-the-account"
        let cache = BalanceCache()
        let xor = WalletAssetId.xor.rawValue
        let saved = [BalanceData(identifier: xor, balance: AmountDecimal(value: 5))]

        // What `BalanceProviderFactory` builds: a provider on the account's cache entry.
        func balanceProvider(answering balances: [BalanceData], requests: Counter) -> SingleValueProvider<[BalanceData]> {
            SingleValueProvider(
                targetIdentifier: account,
                source: AnySingleValueProviderSource {
                    requests.increment()
                    return CompoundOperationWrapper(targetOperation: ClosureOperation<[BalanceData]?> { balances })
                },
                repository: AnyDataProviderRepository(cache),
                updateTrigger: DataProviderEventTrigger.onInitialization
            )
        }

        // A wallet with its asset list: the balances are loaded and cached.
        let firstRequests = Counter()
        let withList = AssetProvider(assetInfos: xorAndVal) { _ in
            balanceProvider(answering: saved, requests: firstRequests)
        }
        XCTAssertTrue(waitOnMain { withList.getBalances(with: [xor]) == saved })
        XCTAssertEqual(firstRequests.value, 1)
        XCTAssertEqual(cache.balances(of: account), saved)

        // The tabs built before any list has arrived: with no asset the node
        // has no balance to give, and that answer must not be saved.
        let emptyRequests = Counter()
        let withoutList = AssetProvider(assetInfos: []) { _ in
            balanceProvider(answering: [], requests: emptyRequests)
        }
        XCTAssertFalse(waitOnMain(for: 0.5) { emptyRequests.value > 0 }, "nothing is asked without an asset list")
        XCTAssertEqual(cache.balances(of: account), saved, "the cached balances are not replaced by an empty list")
        XCTAssertTrue(withoutList.getBalances(with: [xor]).isEmpty)

        // The list arrives and the tabs are built again: they get the balances.
        let rebuiltRequests = Counter()
        let rebuilt = AssetProvider(assetInfos: xorAndVal) { _ in
            balanceProvider(answering: saved, requests: rebuiltRequests)
        }
        XCTAssertTrue(waitOnMain { rebuilt.getBalances(with: [xor]) == saved })
        XCTAssertEqual(cache.balances(of: account), saved)
        withExtendedLifetime((withList, withoutList, rebuilt)) {}
    }
}
