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
    case invalidAsset
    case invalidStorageResponse
    case unrepresentableBalance
}

final class PortfolioSora2BalanceReader: PortfolioSora2BalanceReading {
    private let engine: () -> JSONRPCEngine?
    private let runtime: () -> RuntimeCodingServiceProtocol?
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
    }

    func balances(address: String, assets: [(id: String, precision: Int16)]) async throws -> [String: PortfolioRawBalance] {
        try Task.checkCancellation()
        guard let engine = engine(), let runtime = runtime() else { throw PortfolioReaderError.noConnection }
        guard let accountId = (address as AccountAddress).accountId else { throw PortfolioReaderError.invalidAddress }
        let xorId = WalletAssetId.xor.rawValue
        var seen = Set<Data>()
        for asset in assets {
            guard (0...255).contains(asset.precision),
                  let identifier = try? Data.sora(hex: asset.id), identifier.count == 32,
                  seen.insert(identifier).inserted else { throw PortfolioReaderError.invalidAsset }
        }

        var result: [String: PortfolioRawBalance] = [:]
        if let xor = assets.first(where: { $0.id == xorId }) {
            let info = try await accountInfo(accountId: accountId, engine: engine, runtime: runtime)
            if let data = info?.data {
                result[xorId] = PortfolioRawBalance(
                    free: try amount(data.free, precision: xor.precision),
                    reserved: try amount(data.reserved, precision: xor.precision),
                    frozen: try amount(max(data.miscFrozen, data.feeFrozen), precision: xor.precision)
                )
            } else {
                result[xorId] = .zero
            }
        }

        let tokens = assets.filter { $0.id != xorId }
        guard !tokens.isEmpty else { return result }
        let keyFactory = StorageKeyFactory()
        var keyToAsset: [Data: (id: String, precision: Int16)] = [:]
        for token in tokens {
            let key = try keyFactory.accountsKey(account: accountId, asset: Data.sora(hex: token.id))
            keyToAsset[key] = token
        }
        let values = try await storageValues(keys: Array(keyToAsset.keys), engine: engine)
        for (key, token) in keyToAsset {
            guard let value = values[key] ?? nil else {
                result[token.id] = .zero
                continue
            }
            let decoder = try ScaleDecoder(data: value)
            let data = try OrmlAccountData(scaleDecoder: decoder)
            guard decoder.remained == 0 else { throw PortfolioReaderError.invalidStorageResponse }
            result[token.id] = PortfolioRawBalance(
                free: try amount(data.free.value, precision: token.precision),
                reserved: try amount(data.reserved.value, precision: token.precision),
                frozen: try amount(data.frozen.value, precision: token.precision)
            )
        }
        return result
    }

    /// Convert the complete integer without NSDecimalNumber's exception-raising underflow behavior.
    /// A value the display type cannot represent exactly remains unavailable, never rounded to zero.
    private func amount(_ raw: BigUInt, precision: Int16) throws -> Decimal {
        if raw.isZero { return .zero }
        let digits = String(raw)
        let scale = Int(precision)
        let padded = String(repeating: "0", count: max(0, scale + 1 - digits.count)) + digits
        let split = padded.index(padded.endIndex, offsetBy: -scale)
        let text = scale == 0 ? padded : String(padded[..<split]) + "." + String(padded[split...])
        guard let value = Decimal.parseLocalizedAmount(text, locale: Locale(identifier: "en_US_POSIX")) else {
            throw PortfolioReaderError.unrepresentableBalance
        }
        return value
    }

    /// A null value is an authoritative absence. Missing, duplicate, foreign or malformed changes
    /// are incomplete reads and must not be presented as zero balances.
    private func storageValues(keys: [Data], engine: JSONRPCEngine) async throws -> [Data: Data?] {
        let operation = JSONRPCOperation<[[String]], [StorageUpdate]>(
            engine: engine, method: RPCMethod.queryStorageAt,
            parameters: [keys.map { $0.toHex(includePrefix: true) }]
        )
        let updates = try await run(operation)
        guard updates.count == 1, let changes = updates.first?.changes else {
            throw PortfolioReaderError.invalidStorageResponse
        }
        let requested = Set(keys)
        var values: [Data: Data?] = [:]
        for change in changes {
            guard change.count == 2, let encodedKey = change[0],
                  let key = try? Data.sora(hex: encodedKey), requested.contains(key),
                  !values.keys.contains(key) else { throw PortfolioReaderError.invalidStorageResponse }
            if let encodedValue = change[1] {
                guard let value = try? Data.sora(hex: encodedValue) else {
                    throw PortfolioReaderError.invalidStorageResponse
                }
                values.updateValue(value, forKey: key)
            } else {
                values.updateValue(nil, forKey: key)
            }
        }
        guard Set(values.keys) == requested else { throw PortfolioReaderError.invalidStorageResponse }
        return values
    }

    private func accountInfo(accountId: Data, engine: JSONRPCEngine,
                             runtime: RuntimeCodingServiceProtocol) async throws -> AccountInfo? {
        let factory = try await run(runtime.fetchCoderFactoryOperation())
        let key = try StorageKeyFactory().accountInfoKeyForId(accountId)
        let values = try await storageValues(keys: [key], engine: engine)
        guard let data = values[key] ?? nil else { return nil }
        let operation = StorageDecodingOperation<AccountInfo>(path: .account, data: data)
        operation.codingFactory = factory
        return try await run(operation)
    }

    /// Enqueues `operation` (its dependencies must already be queued) and awaits its result.
    private func run<T>(_ operation: BaseOperation<T>) async throws -> T {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler(operation: {
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
