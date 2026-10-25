// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SSFStorageQueryKitFixed
import SSFUtils

/// One asset balance as the chain stores it, converted with the asset's precision.
struct PortfolioRawBalance: Equatable {
    let free: Decimal
    let reserved: Decimal
    /// The part of `free` that is frozen (locks, staking).
    let frozen: Decimal

    /// Total balance as the app defines it (`BalanceContext.total`).
    var total: Decimal { free + reserved }
    /// What can move now (`BalanceContext.available`).
    var transferable: Decimal { max(0, free - frozen) }

    static let zero = PortfolioRawBalance(free: 0, reserved: 0, frozen: 0)
}

/// Reads the SORA2 balances of any address. Storage queries only: it holds no signer and never
/// touches keys, account storage or the selected wallet.
protocol PortfolioSora2BalanceReading: AnyObject {
    func balances(address: String, assets: [(id: String, precision: Int16)]) async throws -> [String: PortfolioRawBalance]
}

enum PortfolioReaderError: Error {
    case noConnection
    case invalidAddress
}

final class PortfolioSora2BalanceReader: PortfolioSora2BalanceReading {
    private let engine: () -> JSONRPCEngine?
    private let runtime: () -> RuntimeCodingServiceProtocol?
    private let requestFactory: StorageRequestFactoryProtocol
    private let queue: OperationQueue

    init(engine: @escaping () -> JSONRPCEngine? = {
             ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash())
         },
         runtime: @escaping () -> RuntimeCodingServiceProtocol? = {
             ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash())
         },
         queue: OperationQueue = OperationManagerFacade.sharedDefaultQueue) {
        self.engine = engine
        self.runtime = runtime
        self.queue = queue
        requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory() as StorageKeyFactoryProtocol,
                                               operationManager: OperationManagerFacade.sharedManager)
    }

    func balances(address: String, assets: [(id: String, precision: Int16)]) async throws -> [String: PortfolioRawBalance] {
        guard let engine = engine(), let runtime = runtime() else { throw PortfolioReaderError.noConnection }
        guard let accountId = (address as AccountAddress).accountId else { throw PortfolioReaderError.invalidAddress }

        var result: [String: PortfolioRawBalance] = [:]
        let xorId = WalletAssetId.xor.rawValue

        if let xor = assets.first(where: { $0.id == xorId }) {
            let info = try await accountInfo(accountId: accountId, engine: engine, runtime: runtime)
            if let data = info?.data {
                let free = Decimal.fromSubstrateAmount(data.free, precision: xor.precision) ?? 0
                let reserved = Decimal.fromSubstrateAmount(data.reserved, precision: xor.precision) ?? 0
                let frozen = max(Decimal.fromSubstrateAmount(data.miscFrozen, precision: xor.precision) ?? 0,
                                 Decimal.fromSubstrateAmount(data.feeFrozen, precision: xor.precision) ?? 0)
                result[xorId] = PortfolioRawBalance(free: free, reserved: reserved, frozen: frozen)
            } else {
                result[xorId] = .zero
            }
        }

        let tokens = assets.filter { $0.id != xorId }
        guard !tokens.isEmpty else { return result }
        let keyFactory = StorageKeyFactory()
        var keyToAsset: [Data: (id: String, precision: Int16)] = [:]
        var keys: [String] = []
        for token in tokens {
            guard let assetData = try? Data.sora(hex: token.id),
                  let key = try? keyFactory.accountsKey(account: accountId, asset: assetData) else { continue }
            keyToAsset[key] = token
            keys.append(key.toHex(includePrefix: true))
        }
        guard !keys.isEmpty else { return result }

        let operation = JSONRPCOperation<[[String]], [StorageUpdate]>(engine: engine,
                                                                       method: RPCMethod.queryStorageAt,
                                                                       parameters: [keys])
        let updates = try await run(operation)
        for token in tokens { result[token.id] = .zero }
        for change in updates.flatMap({ StorageUpdateData(update: $0).changes }) {
            guard let token = keyToAsset[change.key], let value = change.value else { continue }
            let decoder = try ScaleDecoder(data: value)
            let data = try OrmlAccountData(scaleDecoder: decoder)
            result[token.id] = PortfolioRawBalance(
                free: Decimal.fromSubstrateAmount(data.free.value, precision: token.precision) ?? 0,
                reserved: Decimal.fromSubstrateAmount(data.reserved.value, precision: token.precision) ?? 0,
                frozen: Decimal.fromSubstrateAmount(data.frozen.value, precision: token.precision) ?? 0
            )
        }
        return result
    }

    private func accountInfo(accountId: Data, engine: JSONRPCEngine,
                             runtime: RuntimeCodingServiceProtocol) async throws -> AccountInfo? {
        let coderFactoryOperation = runtime.fetchCoderFactoryOperation()
        let wrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]> = requestFactory.queryItems(
            engine: engine,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: StorageCodingPath.account
        )
        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }
        queue.addOperation(coderFactoryOperation)
        wrapper.dependencies.forEach { queue.addOperation($0) }
        let responses = try await run(wrapper.targetOperation)
        return responses.first?.value
    }

    /// Enqueues `operation` (its dependencies must already be queued) and awaits its result.
    private func run<T>(_ operation: BaseOperation<T>) async throws -> T {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
                operation.completionBlock = {
                    do {
                        continuation.resume(returning: try operation.extractNoCancellableResultData())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                queue.addOperation(operation)
            }
        }, onCancel: {
            operation.cancel()
        })
    }
}

/// Reads native XOR of a network account, read-only, with the app's own Nexus read (the one the
/// Wallet tab's network rows and the Networks screen use).
protocol PortfolioNexusBalanceReading: AnyObject {
    func xorBalance(account: NetworkAccount) async throws -> Decimal
}

final class PortfolioNexusBalanceReader: PortfolioNexusBalanceReading {
    private let readClient: NexusToriiReading

    init(readClient: NexusToriiReading = NexusToriiReadClient()) {
        self.readClient = readClient
    }

    func xorBalance(account: NetworkAccount) async throws -> Decimal {
        guard let configuration = NexusNetworkConfiguration.configuration(for: account.networkId),
              WalletNetworkDirectory.current.info(account.networkId).isLive else {
            throw PortfolioReaderError.noConnection
        }
        let current = try await readCurrentNexusXorBalance(account: account, configuration: configuration,
                                                           readClient: readClient)
        return current.quantity.decimalValue ?? 0
    }
}
