// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import SSFUtils
import Foundation
import SSFStorageQueryKitFixed

struct AssetInfoDto: ScaleCodable {
    let symbol: String
    let name: String
    let precision: UInt8
    let isMintable: Bool

    init(scaleDecoder: ScaleDecoding) throws {
        symbol = try String(scaleDecoder: scaleDecoder)
        name = try String(scaleDecoder: scaleDecoder)
        precision = try UInt8(scaleDecoder: scaleDecoder)
        isMintable = try Bool(scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try symbol.encode(scaleEncoder: scaleEncoder)
        try name.encode(scaleEncoder: scaleEncoder)
        try precision.encode(scaleEncoder: scaleEncoder)
        try isMintable.encode(scaleEncoder: scaleEncoder)
    }
}

protocol AssetsInfoProviderProtocol: AnyObject {
    /// Starts loading in the background and returns at once. `completion` is
    /// called once, on a background queue, with a list that is never empty.
    /// A second call does nothing.
    func load(completion: @escaping ([AssetInfo]) -> Void)

    /// Asks for the next attempt now instead of at the end of the current
    /// wait, for example because the node has just connected. Attempts stay
    /// at least `RetryPolicy.minimumRoundInterval` apart, and further apart
    /// on a node whose last attempts failed (see
    /// `RetryPolicy.wakeUpInterval`), so a node that keeps connecting and
    /// failing is asked with the same growing waits as one that stays
    /// connected. `resettingBackoff` is for an explicit user action: the
    /// waits start from the shortest again.
    func retryNow(resettingBackoff: Bool)

    /// Stops loading. No request stays queued on the connection.
    func cancel()
}

enum AssetsInfoProviderError: Error {
    case timeout
}

/// Loads the list of assets registered on chain (`Assets.AssetInfos`) in the
/// background. Nothing waits for it: the wallet starts with the list saved by
/// the last session and receives this one when it arrives.
///
/// One attempt ("round") reads every page of storage keys from the first page
/// and then the values of those keys. A round that fails for any reason
/// (a page fails or times out, the node has no keys, the values come back
/// empty) is abandoned as a whole, and the next round starts from the first
/// page after a wait that doubles up to a ceiling. So:
/// - a failed first page can never leave an empty key list behind;
/// - the values are never requested without keys;
/// - nothing is sent while the connection is not connected, and a request
///   that timed out is taken off the connection, so a node that comes back
///   finds no queue of old requests;
/// - a retry is a timer, never a call from the failed attempt, so the stack
///   does not grow however long the node stays away.
final class AssetsInfoProvider: AssetsInfoProviderProtocol {
    typealias Connection = JSONRPCEngine & ConnectionStateReporting

    /// Starts a timer and returns a closure that cancels it.
    typealias Timer = (_ delay: TimeInterval, _ fire: @escaping () -> Void) -> () -> Void

    struct RetryPolicy: Equatable {
        /// The wait after the first failed round. It doubles (`multiplier`)
        /// after each further failure.
        var initialDelay: TimeInterval = 2
        var multiplier: Double = 2
        /// No wait is longer than this.
        var maximumDelay: TimeInterval = 60
        /// Each wait is shortened by a random share of up to this fraction,
        /// so that clients do not retry in step when a node returns.
        var jitter: Double = 0.2
        /// Rounds asked for with `retryNow` start at least this far apart.
        /// On a node whose last rounds failed the distance grows, see
        /// `wakeUpInterval(afterFailures:)`.
        var minimumRoundInterval: TimeInterval = 5
        /// The largest page a Substrate node serves.
        var keysPageSize: UInt32 = 1_000
        /// A node that keeps returning full pages ends the round here.
        var maximumKeyPages = 32
        var keysPageTimeout: TimeInterval = 20
        var assetInfosTimeout: TimeInterval = 60

        /// The wait after `failures` failed rounds in a row (1 or more);
        /// `random` is in 0..<1.
        func delay(afterFailures failures: Int, random: Double) -> TimeInterval {
            let exponent = Double(min(max(failures, 1), 64) - 1)
            let base = min(maximumDelay, initialDelay * pow(multiplier, exponent))
            let spread = min(max(jitter, 0), 1) * min(max(random, 0), 1)
            return max(0, base * (1 - spread))
        }

        /// The least distance between two rounds on the same node when the
        /// second one is asked for by `retryNow`, after `failures` failed
        /// rounds in a row on that node: `minimumRoundInterval`, doubled
        /// (`multiplier`) by each further failure, up to `maximumDelay`
        /// (5, 10, 20, 40 and then 60 s).
        ///
        /// Without this a wake-up replaced the planned, backed-off attempt
        /// by one `minimumRoundInterval` after the last, however many rounds
        /// had failed. The chain registry wakes the loader every time a node
        /// connects, so a node that accepted the socket and dropped it again
        /// was asked every 5 seconds by every client for as long as it did so.
        func wakeUpInterval(afterFailures failures: Int) -> TimeInterval {
            guard failures > 1 else { return minimumRoundInterval }
            let exponent = Double(min(failures, 64) - 1)
            let ceiling = max(maximumDelay, minimumRoundInterval)
            return min(ceiling, minimumRoundInterval * pow(max(multiplier, 1), exponent))
        }
    }

    /// The rounds on one node since the last list or reset.
    private struct NodeHistory {
        var failedRounds = 0
        var lastRoundStart: TimeInterval
    }

    /// Nodes remembered at a time. A wallet has a handful of nodes; the
    /// limit only keeps the memory bounded whatever the node list becomes.
    private static let rememberedNodes = 16

    private struct InFlightRequest {
        let serial: UInt64
        let requestId: UInt16
        weak var engine: Connection?
        let cancelTimeout: () -> Void
    }

    private let connection: () -> Connection?
    private let chainId: () -> String
    private let assetInfoKey: String
    private let policy: RetryPolicy
    private let timer: Timer
    private let now: () -> TimeInterval
    private let random: () -> Double
    private let logger: LoggerProtocol?
    private let queue: DispatchQueue

    // Everything below is read and written on `queue` only.
    private var completion: (([AssetInfo]) -> Void)?
    private var isStarted = false
    private var isFinished = false
    private var isCancelled = false
    private var isRoundActive = false
    private var failedRounds = 0
    private var idleChecks = 0
    private var lastRoundStart: TimeInterval?
    private var nodeHistory: [String: NodeHistory] = [:]
    private var roundNode: String?
    private var keys: [String] = []
    private var lastKey: String?
    private var loadedPages = 0
    private var requestSerial: UInt64 = 0
    private var inFlight: InFlightRequest?
    private var scheduleSerial: UInt64 = 0
    private var cancelScheduledRound: (() -> Void)?
    private var scheduledRoundTime: TimeInterval?

    /// - Parameters:
    ///   - connection: the connection to use for the next round, asked again
    ///     for every round. `nil`, or a connection that is not connected,
    ///     means "not now": nothing is sent and the provider looks again later.
    ///   - chainId: the chain the assets belong to, read when a list arrives.
    ///   - timer: the timeouts and the waits between attempts. `nil` (the
    ///     app) runs them on `queue`; see `timer(on:)`.
    ///   - queue: a serial queue; all work of the provider runs on it.
    init(
        connection: @escaping () -> Connection?,
        storageKeyFactory: StorageKeyFactoryProtocol,
        chainId: @escaping () -> String = { "" },
        policy: RetryPolicy = RetryPolicy(),
        timer: Timer? = nil,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        random: @escaping () -> Double = { Double.random(in: 0 ..< 1) },
        logger: LoggerProtocol? = Logger.shared,
        queue: DispatchQueue = DispatchQueue(label: "co.jp.soramitsu.sora.assets-info")
    ) {
        self.connection = connection
        self.chainId = chainId
        assetInfoKey = try! storageKeyFactory.assetsInfoKeysPaged().toHex(includePrefix: true)
        self.policy = policy
        self.timer = timer ?? Self.timer(on: queue)
        self.now = now
        self.random = random
        self.logger = logger
        self.queue = queue
    }

    deinit {
        // No other reference exists any more, so the state can be read here.
        cancelScheduledRound?()
        if let inFlight {
            inFlight.cancelTimeout()
            inFlight.engine?.cancelForIdentifier(inFlight.requestId)
        }
    }

    /// Timers that fire on `queue`, the provider's own serial queue.
    ///
    /// They used to fire on the shared utility queue. That queue has a limited
    /// number of threads for the whole app, and a wallet that opens puts many
    /// blocking requests on the shared queues at once. While those wait for a
    /// slow node no shared thread is free, so a 20 s timeout fired after 47 s
    /// and every later attempt slipped by as much. A serial queue is given a
    /// thread of its own whenever it has work, so the limits keep their length.
    static func timer(on queue: DispatchQueue) -> Timer {
        { delay, fire in
            let item = DispatchWorkItem(block: fire)
            queue.asyncAfter(deadline: .now() + max(0, delay), execute: item)
            return { item.cancel() }
        }
    }

    // MARK: - AssetsInfoProviderProtocol

    func load(completion: @escaping ([AssetInfo]) -> Void) {
        queue.async { [weak self] in
            guard let self, !self.isStarted, !self.isCancelled else { return }
            self.isStarted = true
            self.completion = completion
            self.beginRound()
        }
    }

    func retryNow(resettingBackoff: Bool) {
        queue.async { [weak self] in
            guard let self, self.isLoading else { return }
            if resettingBackoff {
                self.failedRounds = 0
                self.idleChecks = 0
                self.nodeHistory = [:]
            }
            guard !self.isRoundActive else { return }
            let current = self.now()
            let earliest = max(current, self.earliestRoundOnWakeUp())
            if let scheduled = self.scheduledRoundTime, scheduled <= earliest {
                return
            }
            if earliest <= current {
                self.clearScheduledRound()
                self.beginRound()
            } else {
                self.scheduleRound(after: earliest - current)
            }
        }
    }

    func cancel() {
        queue.async { [weak self] in
            guard let self else { return }
            self.isCancelled = true
            self.isRoundActive = false
            self.completion = nil
            self.nodeHistory = [:]
            self.roundNode = nil
            self.clearScheduledRound()
            if let inFlight = self.inFlight {
                self.inFlight = nil
                inFlight.cancelTimeout()
                inFlight.engine?.cancelForIdentifier(inFlight.requestId)
            }
        }
    }

    // MARK: - Rounds

    private var isLoading: Bool {
        isStarted && !isFinished && !isCancelled
    }

    /// The earliest time at which a round asked for by `retryNow` may start.
    private func earliestRoundOnWakeUp() -> TimeInterval {
        var earliest = (lastRoundStart ?? -.infinity) + policy.minimumRoundInterval
        // The node that is connected now. Another node (the registry failed
        // over) has no failed round yet and is asked without a longer wait.
        if let engine = connection(), let history = nodeHistory[Self.nodeKey(of: engine)] {
            earliest = max(
                earliest,
                history.lastRoundStart + policy.wakeUpInterval(afterFailures: history.failedRounds)
            )
        }
        return earliest
    }

    private static func nodeKey(of engine: Connection) -> String {
        engine.url?.absoluteString ?? ""
    }

    private func rememberRoundStart(on node: String, at start: TimeInterval) {
        if nodeHistory[node] == nil, nodeHistory.count >= Self.rememberedNodes,
           let oldest = nodeHistory.min(by: { $0.value.lastRoundStart < $1.value.lastRoundStart }) {
            nodeHistory[oldest.key] = nil
        }
        nodeHistory[node, default: NodeHistory(lastRoundStart: start)].lastRoundStart = start
    }

    private func beginRound() {
        guard isLoading, !isRoundActive else { return }
        guard let engine = connection(), case .connected = engine.state else {
            // Not an attempt: nothing was sent. Look again later.
            idleChecks += 1
            scheduleRound(after: policy.delay(afterFailures: idleChecks, random: random()))
            return
        }
        idleChecks = 0
        isRoundActive = true
        let start = now()
        lastRoundStart = start
        let node = Self.nodeKey(of: engine)
        roundNode = node
        rememberRoundStart(on: node, at: start)
        keys = []
        lastKey = nil
        loadedPages = 0
        requestKeysPage(over: engine)
    }

    private func requestKeysPage(over engine: Connection) {
        var parameters: [JSONAny] = [JSONAny(assetInfoKey), JSONAny(policy.keysPageSize)]
        if let lastKey {
            parameters.append(JSONAny(lastKey))
        }
        send(RPCMethod.getStorageKeysPaged, parameters: parameters,
             timeout: policy.keysPageTimeout, over: engine) { [weak self] (result: Result<[String], Error>) in
            guard let self, self.isRoundActive else { return }
            switch result {
            case let .success(page):
                self.keys.append(contentsOf: page)
                self.loadedPages += 1
                if page.count < Int(self.policy.keysPageSize) {
                    self.requestAssetInfos(over: engine)
                } else if page.last == self.lastKey {
                    // The node did not move on from the start key.
                    self.roundFailed("key_page_repeated")
                } else if self.loadedPages >= self.policy.maximumKeyPages {
                    self.roundFailed("key_page_limit")
                } else {
                    self.lastKey = page.last
                    self.requestKeysPage(over: engine)
                }
            case .failure:
                self.roundFailed("key_page")
            }
        }
    }

    private func requestAssetInfos(over engine: Connection) {
        guard !keys.isEmpty else {
            // A node without asset keys cannot answer a value query.
            roundFailed("no_keys")
            return
        }
        send(RPCMethod.queryStorageAt, parameters: [keys],
             timeout: policy.assetInfosTimeout, over: engine) { [weak self] (result: Result<[StorageUpdate], Error>) in
            guard let self, self.isRoundActive else { return }
            guard case let .success(updates) = result, let update = updates.first else {
                self.roundFailed("asset_infos")
                return
            }
            let assets = Self.assets(from: update, chainId: self.chainId())
            guard !assets.isEmpty else {
                self.roundFailed("empty_asset_infos")
                return
            }
            self.finish(with: assets)
        }
    }

    private func finish(with assets: [AssetInfo]) {
        isRoundActive = false
        isFinished = true
        keys = []
        nodeHistory = [:]
        roundNode = nil
        clearScheduledRound()
        let completion = self.completion
        self.completion = nil
        completion?(assets)
    }

    private func roundFailed(_ code: String) {
        isRoundActive = false
        keys = []
        lastKey = nil
        failedRounds += 1
        if let roundNode {
            // Gone after a reset (`retryNow(resettingBackoff: true)`): the
            // count for this node then starts with its next round.
            nodeHistory[roundNode]?.failedRounds += 1
        }
        roundNode = nil
        let delay = policy.delay(afterFailures: failedRounds, random: random())
        // A fixed code and numbers only: never keys or node answers.
        logger?.warning("Asset list: attempt \(failedRounds) failed (\(code)); next in \(Int(delay.rounded())) s")
        scheduleRound(after: delay)
    }

    private func scheduleRound(after delay: TimeInterval) {
        clearScheduledRound()
        scheduleSerial += 1
        let serial = scheduleSerial
        scheduledRoundTime = now() + delay
        cancelScheduledRound = timer(delay) { [weak self] in
            self?.queue.async {
                guard let self, self.scheduleSerial == serial, self.cancelScheduledRound != nil else { return }
                self.cancelScheduledRound = nil
                self.scheduledRoundTime = nil
                self.beginRound()
            }
        }
    }

    private func clearScheduledRound() {
        cancelScheduledRound?()
        cancelScheduledRound = nil
        scheduledRoundTime = nil
    }

    // MARK: - Requests

    /// Sends one request. `handler` is called exactly once on `queue`: with the
    /// answer, or with a failure after `timeout`, in which case the request is
    /// also removed from the connection.
    private func send<P: Codable, T: Decodable>(
        _ method: String,
        parameters: P,
        timeout: TimeInterval,
        over engine: Connection,
        handler: @escaping (Result<T, Error>) -> Void
    ) {
        requestSerial += 1
        let serial = requestSerial
        let requestId: UInt16
        do {
            // Not resent after a reconnection: the round fails and the next
            // one starts from the first page.
            requestId = try engine.callMethod(
                method,
                params: parameters,
                options: JSONRPCOptions(resendOnReconnect: false)
            ) { [weak self] (result: Result<T, Error>) in
                self?.queue.async {
                    guard let self, let current = self.inFlight, current.serial == serial else { return }
                    self.inFlight = nil
                    current.cancelTimeout()
                    handler(result)
                }
            }
        } catch {
            handler(.failure(error))
            return
        }
        let cancelTimeout = timer(timeout) { [weak self] in
            self?.queue.async {
                guard let self, let current = self.inFlight, current.serial == serial else { return }
                self.inFlight = nil
                current.engine?.cancelForIdentifier(current.requestId)
                handler(.failure(AssetsInfoProviderError.timeout))
            }
        }
        inFlight = InFlightRequest(serial: serial, requestId: requestId, engine: engine, cancelTimeout: cancelTimeout)
    }

    // MARK: - Decoding

    static func assets(from update: StorageUpdate, chainId: String) -> [AssetInfo] {
        StorageUpdateData(update: update).changes.compactMap { change in
            assetInfo(from: change, chainId: chainId)
        }
    }

    static func assetInfo(from change: StorageUpdateData.StorageUpdateChangeData, chainId: String) -> AssetInfo? {
        guard let assetInfoDto = assetInfoDto(from: change.value) else { return nil }
        let assetId = assetId(from: change.key)
        return AssetInfo(
            id: assetId,
            symbol: assetInfoDto.symbol,
            chainId: chainId,
            precision: UInt32(assetInfoDto.precision),
            icon: nil,
            displayName: assetInfoDto.name,
            visible: [
                WalletAssetId.xor.rawValue,
                WalletAssetId.val.rawValue,
                WalletAssetId.pswap.rawValue,
                WalletAssetId.xst.rawValue,
                WalletAssetId.xstusd.rawValue,
                WalletAssetId.tbcd.rawValue
            ].contains(assetId)
        )
    }

    static func assetId(from assetKey: Data) -> String {
        let hexPrefix = "0x"
        let assetIdWithoutPrefix = assetKey.toHex(includePrefix: true).suffix(64)
        return hexPrefix + assetIdWithoutPrefix
    }

    static func assetInfoDto(from data: Data?) -> AssetInfoDto? {
        guard let data = data else { return nil }
        guard let scaleDecoder = try? ScaleDecoder(data: data) else { return nil }
        return try? AssetInfoDto(scaleDecoder: scaleDecoder)
    }
}

// MARK: - Network work that startup never waits for

protocol StartupNetworkCoordinating: AnyObject {
    /// Called by every run of startup: the launch and every in-app restart
    /// (recovery "Try again", "Set up this iPhone again", Welcome back after a
    /// restore, account removal, node change). Returns at once.
    func startupDidBegin()

    /// Called just before startup boots the chain registry. From then on the
    /// registry's connection, which fails over between nodes, is used, from a
    /// background queue. The caller has created the registry on the main
    /// thread before this call (`SplashInteractor.bootChainRegistry`).
    func chainRegistryWillBoot()
}

/// The network work that startup begins and never waits for.
///
/// Wallet storage checks and routing (PIN, onboarding, Welcome back, the
/// recovery screen) need no node. They used to run only after the remote
/// configuration and the on-chain asset list had been answered, so a dead
/// saved node, a captive network or a slow first request left the app on the
/// splash for good. Now both are requested here, in the background:
///
/// - **Remote configuration.** Startup uses the bundled configuration (and the
///   feature flags saved from the last answer). When PI answers, the node list
///   it adds is given to the chain registry.
/// - **Asset list.** The wallet starts with the list saved in the chain store.
///   The live list is loaded over the chain registry's own connection (the one
///   that fails over between the selected, bundled and configured nodes and
///   records the last node that worked) and is then given to the registry.
///
/// One instance lives for the whole process, so a list that could not be
/// loaded while the splash was visible is still loaded later.
final class StartupNetworkCoordinator: StartupNetworkCoordinating {
    static let shared = StartupNetworkCoordinator()

    typealias ProviderFactory = (_ connection: @escaping () -> AssetsInfoProvider.Connection?) -> AssetsInfoProviderProtocol

    private let configService: ConfigServiceProtocol
    private let chainConnection: () -> AssetsInfoProvider.Connection?
    private let syncChains: () -> Void
    private let publishAssets: ([AssetInfo]) -> Void
    private let makeProvider: ProviderFactory

    private let lock = NSLock()
    private var provider: AssetsInfoProviderProtocol?
    private var hasAssets = false
    private var isRegistryBooted = false
    private var isRefreshingConfig = false

    init(
        configService: ConfigServiceProtocol = ConfigService.shared,
        chainConnection: @escaping () -> AssetsInfoProvider.Connection? = {
            ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash())
        },
        syncChains: @escaping () -> Void = { ChainRegistryFacade.sharedRegistry.syncUp() },
        publishAssets: @escaping ([AssetInfo]) -> Void = { AssetManager.networkAssets = $0 },
        makeProvider: @escaping ProviderFactory = { connection in
            AssetsInfoProvider(
                connection: connection,
                storageKeyFactory: StorageKeyFactory(),
                chainId: { Chain.sora.genesisHash() }
            )
        }
    ) {
        self.configService = configService
        self.chainConnection = chainConnection
        self.syncChains = syncChains
        self.publishAssets = publishAssets
        self.makeProvider = makeProvider
    }

    deinit {
        provider?.cancel()
    }

    func startupDidBegin() {
        refreshRemoteConfig()
        loadAssetsIfNeeded()
    }

    func chainRegistryWillBoot() {
        lock.lock()
        isRegistryBooted = true
        let provider = self.provider
        lock.unlock()
        provider?.retryNow(resettingBackoff: false)
    }

    /// The chain registry's connection has just connected to a node.
    func nodeDidConnect() {
        lock.lock()
        let provider = self.provider
        lock.unlock()
        provider?.retryNow(resettingBackoff: false)
    }

    /// The user asked to try again ("Try again" on the wallet opening screen).
    func retryNow() {
        lock.lock()
        let provider = self.provider
        lock.unlock()
        provider?.retryNow(resettingBackoff: true)
    }

    // MARK: - Remote configuration

    private func refreshRemoteConfig() {
        lock.lock()
        guard !isRefreshingConfig else {
            lock.unlock()
            return
        }
        isRefreshingConfig = true
        lock.unlock()

        let nodesBefore = configService.config.defaultNodes
        // The answer may arrive long after the splash is gone, or never.
        configService.setupConfig { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.isRefreshingConfig = false
            let isRegistryBooted = self.isRegistryBooted
            self.lock.unlock()
            // Before the boot there is nothing to update: the boot itself
            // reads the configuration.
            guard isRegistryBooted, self.configService.config.defaultNodes != nodesBefore else { return }
            self.syncChains()
        }
    }

    // MARK: - Asset list

    private func loadAssetsIfNeeded() {
        lock.lock()
        if hasAssets {
            lock.unlock()
            return
        }
        if let provider {
            lock.unlock()
            // A new run of startup is a user action: try now.
            provider.retryNow(resettingBackoff: true)
            return
        }
        let provider = makeProvider { [weak self] in self?.connectionForAssets() }
        self.provider = provider
        lock.unlock()
        provider.load { [weak self] assets in
            self?.didLoad(assets)
        }
    }

    private func connectionForAssets() -> AssetsInfoProvider.Connection? {
        lock.lock()
        let isRegistryBooted = self.isRegistryBooted
        lock.unlock()
        // The registry is not created for this: while startup has not booted
        // it (recovery screen, low storage, 1.x upgrade) no list is needed.
        return isRegistryBooted ? chainConnection() : nil
    }

    private func didLoad(_ assets: [AssetInfo]) {
        lock.lock()
        hasAssets = true
        provider = nil
        lock.unlock()
        publishAssets(assets)
        // The registry saved the chain before this list existed. Its sync
        // reads the list and updates the chain. `AssetManager` follows the
        // chain and has the wallet's screens built again if they were built
        // without any asset.
        syncChains()
        Logger.shared.info("Asset list: \(assets.count) assets loaded")
    }
}
