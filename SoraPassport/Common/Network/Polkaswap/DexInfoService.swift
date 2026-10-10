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
import Foundation
import SSFUtils
import SSFStorageQueryKitFixed

/// A DEX on SORA and the asset its pools are quoted in.
struct DexInfo: Equatable {
    let id: UInt32
    let baseAssetId: String
}

enum DexInfoError: Error {
    case noConnection
    case noDexes
}

protocol DexInfoLoading {
    /// Reads `DEXManager.DEXInfos` once. Calls `completion` exactly once.
    func loadDexInfos(completion: @escaping (Result<[DexInfo], Error>) -> Void)
}

/// The DEX ids of the live chain, read from `DEXManager.DEXInfos`. Mainnet has
/// 0 (XOR), 1 (XSTUSD), 2 (KUSD) and 3 (VXOR) today; earlier 3.9.0 builds hard-coded
/// 0 and 1, so they could not quote or trade through the others.
///
/// Compared with App Store 3.8.6's `DexInfoServiceDefault`:
/// - an unknown base asset costs at most one chain read and is then reported as
///   unknown (3.8.6 called itself without end when the asset was not a DEX base);
/// - one chain read runs at a time, and after a failure the next one waits
///   `retryInterval`;
/// - the genesis DEXes (0 for XOR, 1 for XSTUSD) are always known, so a failed read
///   never blocks swaps or liquidity in XOR and XSTUSD pools;
/// - operation completions are set before the operations are enqueued.
final class DexInfoService {
    static let shared = DexInfoService(loader: ChainDexInfoLoader())

    static let genesisDexes = [
        DexInfo(id: 0, baseAssetId: WalletAssetId.xor.rawValue),
        DexInfo(id: 1, baseAssetId: WalletAssetId.xstusd.rawValue)
    ]

    static let retryInterval: TimeInterval = 30

    private let loader: DexInfoLoading
    private let now: () -> Date
    private let lock = NSLock()
    private var chainDexes: [DexInfo]?
    private var lastFailure: Date?
    private var isLoading = false
    private var waiters: [([DexInfo]) -> Void] = []

    init(loader: DexInfoLoading, now: @escaping () -> Date = Date.init) {
        self.loader = loader
        self.now = now
    }

    /// The DEXes known now, without waiting: the chain's list once it was read, else the
    /// genesis DEXes.
    var knownDexes: [DexInfo] {
        lock.lock()
        defer { lock.unlock() }
        return chainDexes ?? Self.genesisDexes
    }

    /// The DEX whose pools are quoted in this asset, from what is known now.
    func knownDexId(forBaseAssetId assetId: String) -> UInt32? {
        Self.dexId(forBaseAssetId: assetId, in: knownDexes)
    }

    /// The chain's DEXes. Reads them first when they have not been read yet; if the read
    /// fails, returns the genesis DEXes.
    func dexes(completion: @escaping ([DexInfo]) -> Void) {
        lock.lock()
        if let chainDexes {
            lock.unlock()
            completion(chainDexes)
            return
        }
        if let lastFailure, now().timeIntervalSince(lastFailure) < Self.retryInterval {
            lock.unlock()
            completion(Self.genesisDexes)
            return
        }
        waiters.append(completion)
        let startsRead = !isLoading
        isLoading = true
        lock.unlock()

        guard startsRead else { return }
        loader.loadDexInfos { result in
            self.finishRead(with: result)
        }
    }

    func dexes() async -> [DexInfo] {
        await withCheckedContinuation { continuation in
            dexes { continuation.resume(returning: $0) }
        }
    }

    /// The DEX for a base asset: from what is known, else after one chain read. `nil`
    /// when the asset is not the base asset of any DEX.
    func dexId(forBaseAssetId assetId: String, completion: @escaping (UInt32?) -> Void) {
        if let known = knownDexId(forBaseAssetId: assetId) {
            completion(known)
            return
        }
        dexes { dexes in
            completion(Self.dexId(forBaseAssetId: assetId, in: dexes))
        }
    }

    func dexId(forBaseAssetId assetId: String) async -> UInt32? {
        await withCheckedContinuation { continuation in
            dexId(forBaseAssetId: assetId) { continuation.resume(returning: $0) }
        }
    }

    /// Reads the chain's DEXes in the background so later lookups need not wait.
    func prefetch() {
        dexes { _ in }
    }

    private func finishRead(with result: Result<[DexInfo], Error>) {
        lock.lock()
        switch result {
        case let .success(dexes) where !dexes.isEmpty:
            chainDexes = dexes.sorted { $0.id < $1.id }
            lastFailure = nil
        default:
            lastFailure = now()
        }
        let resolved = chainDexes ?? Self.genesisDexes
        let pending = waiters
        waiters = []
        isLoading = false
        lock.unlock()

        pending.forEach { $0(resolved) }
    }

    private static func dexId(forBaseAssetId assetId: String, in dexes: [DexInfo]) -> UInt32? {
        let wanted = assetId.lowercased()
        return dexes.first { $0.baseAssetId.lowercased() == wanted }?.id
    }
}

/// Reads `DEXManager.DEXInfos` over the connected SORA node.
final class ChainDexInfoLoader: DexInfoLoading {
    private let engineProvider: () -> JSONRPCEngine?
    private let operationQueue: OperationQueue

    init(
        engineProvider: @escaping () -> JSONRPCEngine? = {
            ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash())
        },
        operationQueue: OperationQueue = OperationQueue()
    ) {
        self.engineProvider = engineProvider
        self.operationQueue = operationQueue
    }

    func loadDexInfos(completion: @escaping (Result<[DexInfo], Error>) -> Void) {
        guard let engine = engineProvider(),
              let prefix = try? StorageKeyFactory().createStorageKey(
                moduleName: "DEXManager",
                storageName: "DEXInfos"
              ) else {
            completion(.failure(DexInfoError.noConnection))
            return
        }

        let keysOperation = JSONRPCOperation<[JSONAny], [String]>(
            engine: engine,
            method: RPCMethod.getStorageKeysPaged,
            parameters: [JSONAny(prefix.toHex(includePrefix: true)), JSONAny(UInt32(100))]
        )
        keysOperation.completionBlock = { [operationQueue] in
            let keys: [String]
            do {
                keys = try keysOperation.extractResultData(throwing: DexInfoError.noDexes)
            } catch {
                completion(.failure(error))
                return
            }
            guard !keys.isEmpty else {
                completion(.failure(DexInfoError.noDexes))
                return
            }

            let valuesOperation = JSONRPCOperation<[[String]], [StorageUpdate]>(
                engine: engine,
                method: RPCMethod.queryStorageAt,
                parameters: [keys]
            )
            valuesOperation.completionBlock = {
                do {
                    let updates = try valuesOperation.extractResultData(throwing: DexInfoError.noDexes)
                    let changes = updates.flatMap { StorageUpdateData(update: $0).changes }
                    let dexes = Self.decode(
                        changes.map { (key: $0.key, value: $0.value) },
                        prefix: prefix
                    )
                    completion(dexes.isEmpty ? .failure(DexInfoError.noDexes) : .success(dexes))
                } catch {
                    completion(.failure(error))
                }
            }
            operationQueue.addOperation(valuesOperation)
        }
        operationQueue.addOperation(keysOperation)
    }

    /// `DEXInfos: map twox_64_concat(DEXId: u32) => DEXInfo { base_asset_id, synthetic_base_asset_id,
    /// is_public }`. The key ends with the little-endian DEX id; the value starts with the
    /// 32-byte base asset id. Entries of any other shape are skipped.
    static func decode(_ entries: [(key: Data, value: Data?)], prefix: Data) -> [DexInfo] {
        var byId: [UInt32: DexInfo] = [:]
        for entry in entries {
            let key = entry.key
            guard key.count == prefix.count + 8 + 4,
                  key.prefix(prefix.count) == prefix,
                  let value = entry.value,
                  value.count >= 32 + 32 + 1 else {
                continue
            }
            let id = key.suffix(4).reversed().reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            let baseAssetId = Data(value.prefix(32)).toHex(includePrefix: true)
            if byId[id] == nil {
                byId[id] = DexInfo(id: id, baseAssetId: baseAssetId)
            }
        }
        return byId.values.sorted { $0.id < $1.id }
    }
}
