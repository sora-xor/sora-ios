// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CryptoKit
import Foundation
import IrohaCrypto
import NexusTransferCodec

/// Faucet claims use only a public receive address. The pending hash is saved
/// before dispatch so reopening the screen checks that claim instead of minting
/// again after a lost response.
actor TairaFaucetService {
    static let shared = TairaFaucetService()

    enum Phase { case preparing, submitting, checking }
    enum Failure: Error { case busy, wrongAccount, unreadableRequest }

    struct PendingClaim: Codable, Equatable {
        let network: String
        let account: String
        let transactionHash: String
        let amount: String
    }

    private let client: TairaFaucetClient
    private let directory: URL?
    private var active: Set<String> = []

    init(client: TairaFaucetClient? = nil, directory: URL? = nil) {
        self.client = client ?? TairaFaucetClient(scrypt: { nonce, salt, n, r, p in
            try Self.scrypt(nonce, salt, n, r, p)
        })
        self.directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first?.appendingPathComponent("SORA/TairaFaucet", isDirectory: true)
    }

    nonisolated static func scrypt(
        _ nonce: Data, _ salt: Data, _ n: UInt64, _ r: UInt32, _ p: UInt32
    ) throws -> Data {
        try autoreleasepool {
            try IRScryptKeyDeriviation().deriveKey(
                from: nonce, salt: salt, scryptN: UInt(n),
                scryptP: UInt(p), scryptR: UInt(r), length: 32
            )
        }
    }

    nonisolated static func validatedPublicKey(
        account: NetworkAccount, configuration: NexusNetworkConfiguration
    ) throws -> Data {
        guard account.networkId == .taira, configuration.networkId == .taira,
              configuration.isLive, configuration.satisfiesCurrentTairaContract else {
            throw Failure.wrongAccount
        }
        let address = try IrohaAddressCodec.parse(
            account.address, expectedDiscriminant: configuration.i105Discriminant
        )
        let key = try Data(hex: address.publicKeyHex)
        guard key == account.publicKey else { throw Failure.wrongAccount }
        return key
    }

    func hasPending(account: String) throws -> Bool {
        try load(account: account) != nil
    }

    func request(
        account: NetworkAccount,
        configuration: NexusNetworkConfiguration,
        contextIsCurrent: @escaping @Sendable () async -> Bool,
        progress: @escaping @Sendable (Phase) async -> Void
    ) async throws -> TairaFaucetClient.Outcome {
        let key = try Self.validatedPublicKey(account: account, configuration: configuration)
        guard active.insert(account.address).inserted else { throw Failure.busy }
        defer { active.remove(account.address) }
        try Task.checkCancellation()
        guard await contextIsCurrent() else { throw Failure.wrongAccount }

        if let pending = try load(account: account.address) {
            await progress(.checking)
            let outcome = try await client.resume(
                transactionHash: pending.transactionHash, amount: pending.amount
            )
            finish(outcome, account: account.address)
            return outcome
        }

        await progress(.preparing)
        let prepared = try await client.prepare(account: account.address, publicKey: key)
        await progress(.submitting)
        try Task.checkCancellation()
        guard await contextIsCurrent() else { throw Failure.wrongAccount }
        let pending = PendingClaim(network: TairaClient.networkLiteral, account: account.address,
            transactionHash: prepared.transactionHash, amount: prepared.amount)
        try save(pending)
        let submitted: TairaFaucetClient.Outcome
        do {
            submitted = try await client.submit(prepared)
        } catch {
            // These failures are definitive: cancellation/expiry happen before
            // dispatch, and HTTP 429 rejects the request without accepting it.
            var notSubmitted = error is CancellationError
            if let failure = error as? TairaFaucetClient.Failure {
                switch failure {
                case .expired, .rateLimited: notSubmitted = true
                default: break
                }
            }
            if notSubmitted, let url = try? path(account: account.address) {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }
        switch submitted.state {
        case .applied, .rejected:
            finish(submitted, account: account.address)
            return submitted
        case .pending:
            await progress(.checking)
            let outcome = try await client.resume(
                transactionHash: pending.transactionHash, amount: pending.amount
            )
            finish(outcome, account: account.address)
            return outcome
        }
    }

    private func path(account: String) throws -> URL {
        guard let directory else { throw Failure.unreadableRequest }
        let name = SHA256.hash(data: Data((TairaClient.networkLiteral + "\n" + account).utf8))
            .map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name + ".json")
    }

    private func load(account: String) throws -> PendingClaim? {
        let url = try path(account: account)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard data.count <= 4096,
              let pending = try? JSONDecoder().decode(PendingClaim.self, from: data),
              pending.network == TairaClient.networkLiteral, pending.account == account,
              pending.amount == TairaFaucetClient.amount,
              pending.transactionHash.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw Failure.unreadableRequest
        }
        return pending
    }

    private func save(_ pending: PendingClaim) throws {
        let url = try path(account: pending.account)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(pending).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    private func finish(_ outcome: TairaFaucetClient.Outcome, account: String) {
        switch outcome.state {
        case .pending: break
        case .applied, .rejected:
            if let url = try? path(account: account) { try? FileManager.default.removeItem(at: url) }
        }
    }
}
