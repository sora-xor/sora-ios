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
import SoraKeystore
import RobinHood
import IrohaCrypto
import SSFUtils

typealias MigrationResultClosure = (Result<String, Error>) -> Void

enum MigrationServiceError: Error {
    case startMigrationFail
    case confirmMigrationFail
    case typeMappingMissing
}

private enum MigrationFinalityOutcome {
    case finalizedSuccess
    case retrySafeFailure
    case recoveryUnavailable
}

/// Owns one exact migration recovery attempt. The handle is published before
/// its task starts, so a very fast terminal result cannot leave a completed
/// task installed forever. A claim screen opened while background recovery is
/// already running can attach one completion without signing or submitting a
/// second extrinsic.
final class MigrationFinalityRecoveryHandle {
    let accountAddress: String
    let transactionHash: String

    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var completion: MigrationResultClosure?
    private var finished = false

    init(
        accountAddress: String,
        transactionHash: String,
        completion: MigrationResultClosure?
    ) {
        self.accountAddress = accountAddress
        self.transactionHash = transactionHash
        self.completion = completion
    }

    func matches(accountAddress: String, transactionHash: String) -> Bool {
        self.accountAddress == accountAddress &&
            self.transactionHash == transactionHash
    }

    @discardableResult
    func attach(_ completion: @escaping MigrationResultClosure) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished, self.completion == nil else {
            return false
        }
        self.completion = completion
        return true
    }

    func install(_ task: Task<Void, Never>) {
        lock.lock()
        let shouldCancel = finished
        if !finished {
            self.task = task
        }
        lock.unlock()
        if shouldCancel {
            task.cancel()
        }
    }

    func finish() -> MigrationResultClosure? {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else {
            return nil
        }
        finished = true
        task = nil
        let attachedCompletion = completion
        completion = nil
        return attachedCompletion
    }

    func cancel() {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let installedTask = task
        task = nil
        completion = nil
        lock.unlock()
        installedTask?.cancel()
    }
}

/// Serializes the asynchronous `needsMigration` decision. An account switch,
/// a claim submission, or a completed migration invalidates the token so a
/// late response cannot present a second claim screen. A requested migration
/// retains its token through the exact signing boundary, closing the gap
/// before its durable pending-submission row exists.
final class MigrationEligibilityCheckGate {
    private enum Phase: Equatable {
        case awaitingEligibility
        case signingAuthorized
    }

    private struct Check {
        let token: UUID
        let accountAddress: String
        var phase: Phase
    }

    private let lock = NSLock()
    private var current: Check?

    func begin(accountAddress: String) -> UUID? {
        lock.lock()
        defer { lock.unlock() }
        if current?.accountAddress == accountAddress {
            return nil
        }
        let token = UUID()
        current = Check(
            token: token,
            accountAddress: accountAddress,
            phase: .awaitingEligibility
        )
        return token
    }

    func consume(token: UUID, accountAddress: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard
            current?.token == token,
            current?.accountAddress == accountAddress
        else {
            return false
        }
        current = nil
        return true
    }

    func consumeAwaitingEligibility(
        token: UUID,
        accountAddress: String
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard
            current?.token == token,
            current?.accountAddress == accountAddress,
            current?.phase == .awaitingEligibility
        else {
            return false
        }
        current = nil
        return true
    }

    func authorizeForSigning(
        token: UUID,
        accountAddress: String
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard
            current?.token == token,
            current?.accountAddress == accountAddress,
            current?.phase == .awaitingEligibility
        else {
            return false
        }
        current?.phase = .signingAuthorized
        return true
    }

    func validateSigningAuthorization(
        token: UUID,
        accountAddress: String
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return current?.token == token &&
            current?.accountAddress == accountAddress &&
            current?.phase == .signingAuthorized
    }

    func invalidate() {
        lock.lock()
        current = nil
        lock.unlock()
    }
}

/// A fixed-key, dual-read companion to the legacy app-wide `hasMigrated`
/// flag. It records which public SORA2 account received an authoritative
/// completion result without changing or deleting the production key. The
/// marker is advisory only: neither it nor the legacy flag may bypass the
/// live account-bound eligibility check before a new migration signature.
enum MigrationAccountCompletionStore {
    private struct Payload: Codable, Equatable {
        let schemaVersion: Int
        let accountAddresses: [String]
    }

    private static let schemaVersion = 1
    private static let maximumAccounts = 500
    private static let maximumPayloadBytes = 300 * 1_024
    private static let lock = NSLock()

    static func contains(
        accountAddress: String,
        settings: SettingsManagerProtocol
    ) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard isValid(accountAddress) else {
            throw MigrationServiceError.startMigrationFail
        }
        return try load(settings: settings).contains(accountAddress)
    }

    static func record(
        accountAddress: String,
        settings: SettingsManagerProtocol
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard isValid(accountAddress) else {
            throw MigrationServiceError.startMigrationFail
        }
        var addresses = try load(settings: settings)
        addresses.insert(accountAddress)
        guard addresses.count <= maximumAccounts else {
            throw MigrationServiceError.startMigrationFail
        }
        let payload = Payload(
            schemaVersion: schemaVersion,
            accountAddresses: addresses.sorted()
        )
        guard settings.set(
            value: payload,
            for: SettingsKey.migratedAccountsV1.rawValue
        ) else {
            throw MigrationServiceError.startMigrationFail
        }
    }

    static func remove(
        accountAddress: String,
        settings: SettingsManagerProtocol
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard isValid(accountAddress) else {
            throw MigrationServiceError.startMigrationFail
        }
        var addresses = try load(settings: settings)
        addresses.remove(accountAddress)
        if addresses.isEmpty {
            settings.removeValue(
                for: SettingsKey.migratedAccountsV1.rawValue
            )
            guard
                settings.anyValue(
                    for: SettingsKey.migratedAccountsV1.rawValue
                ) == nil
            else {
                throw MigrationServiceError.startMigrationFail
            }
            return
        }
        let payload = Payload(
            schemaVersion: schemaVersion,
            accountAddresses: addresses.sorted()
        )
        guard settings.set(
            value: payload,
            for: SettingsKey.migratedAccountsV1.rawValue
        ) else {
            throw MigrationServiceError.startMigrationFail
        }
    }

    private static func load(
        settings: SettingsManagerProtocol
    ) throws -> Set<String> {
        guard let data = settings.data(
            for: SettingsKey.migratedAccountsV1.rawValue
        ) else {
            return []
        }
        guard
            data.count <= maximumPayloadBytes,
            let payload = try? JSONDecoder().decode(Payload.self, from: data),
            payload.schemaVersion == schemaVersion,
            payload.accountAddresses.count <= maximumAccounts,
            Set(payload.accountAddresses).count ==
                payload.accountAddresses.count,
            payload.accountAddresses == payload.accountAddresses.sorted(),
            payload.accountAddresses.allSatisfy(isValid)
        else {
            throw MigrationServiceError.startMigrationFail
        }
        return Set(payload.accountAddresses)
    }

    private static func isValid(_ accountAddress: String) -> Bool {
        !accountAddress.isEmpty &&
            accountAddress.utf8.count <= 512 &&
            accountAddress == accountAddress.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }
}

protocol MigrationServiceProtocol {
    func checkMigration()
    func requestMigration(completion completionClosure: @escaping MigrationResultClosure)
}

class MigrationService: MigrationServiceProtocol {

    private static let finalityRetryNanoseconds: UInt64 = 6_000_000_000

    var engine: JSONRPCEngine? {
        ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash())
    }
    private(set) var settings: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol
    var runtimeRegistry: RuntimeCodingServiceProtocol? {
        ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash())
    }
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol
    let keystore: KeystoreProtocol
    private let eligibilityGate = MigrationEligibilityCheckGate()
    private let finalityLock = NSLock()
    private var finalityRecovery: MigrationFinalityRecoveryHandle?

    init(eventCenter: EventCenterProtocol,
         keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.logger = logger
        self.operationManager = operationManager
        self.keystore = keystore
    }

    deinit {
        finalityLock.lock()
        let recovery = finalityRecovery
        finalityRecovery = nil
        finalityLock.unlock()
        recovery?.cancel()
        eligibilityGate.invalidate()
    }

    func checkMigration() {
        guard !settings.walletMigrationRecoveryRequired else {
            eligibilityGate.invalidate()
            return
        }
        guard
            let account = SelectedWalletSettings.shared.currentAccount,
            let sourceEngine = engine
        else {
            eligibilityGate.invalidate()
            return
        }
        cancelFinalityRecoveryIfAccountChanged(to: account.address)
        let statusEngine = Sora2BoundedHTTPJSONRPCEngine.wrapping(
            sourceEngine
        )
        guard !resumePendingMigrationIfNeeded(
            account: account,
            engine: statusEngine,
            runtimeRegistry: runtimeRegistry,
            completion: nil
        ) else {
            eligibilityGate.invalidate()
            return
        }
        guard
            let keyPair = createIrohaKeyPair(
                for: account.address
            ),
            let did = createDid(from: keyPair)
        else {
            // Raw-seed and watch-only accounts must never be normalized into
            // an invented mnemonic-backed Iroha identity.
            logger.error("Migration requires the existing master phrase")
            eligibilityGate.invalidate()
            return
        }
        guard let eligibilityToken = eligibilityGate.begin(
            accountAddress: account.address
        ) else {
            return
        }
        do {
            _ = try statusEngine.callMethod(
                RPCMethod.needsMigration,
                params: [did],
                completion: { [weak self] (result: Result<Bool, Error>) in
                    guard let self else { return }
                    switch result {
                    case let .success(migrationNeeded):
                        DispatchQueue.main.async {
                            guard
                                self.eligibilityGate.consume(
                                    token: eligibilityToken,
                                    accountAddress: account.address
                                ),
                                SelectedWalletSettings.shared.currentAccount?
                                    .address == account.address
                            else {
                                return
                            }
                            if migrationNeeded {
                                self.decideMigration()
                            } else {
                                self.migrationSuccess(
                                    accountAddress: account.address
                                )
                            }
                        }
                    case .failure:
                        _ = self.eligibilityGate.consume(
                            token: eligibilityToken,
                            accountAddress: account.address
                        )
                        self.logger.error(
                            "Migration eligibility check failed"
                        )
                    }
                }
            )
        } catch {
            _ = eligibilityGate.consume(
                token: eligibilityToken,
                accountAddress: account.address
            )
            logger.error("Migration eligibility check failed")
        }
    }

    private func decideMigration() {
        eventCenter.notify(with: MigrationEvent(service: self))
    }

    private func migrationSuccess(accountAddress: String) {
        eligibilityGate.invalidate()
        do {
            try MigrationAccountCompletionStore.record(
                accountAddress: accountAddress,
                settings: settings
            )
        } catch {
            // The legacy flag remains available for dual-read compatibility,
            // but neither setting is authority for a later submission. A
            // future check will query this exact account again.
            logger.error("Per-account migration completion was not recorded")
        }
        settings.hasMigrated = true
        eventCenter.notify(with: MigrationSuccsessEvent(service: self))
    }

    func requestMigration(completion completionClosure: @escaping MigrationResultClosure) {
        guard let account = SelectedWalletSettings.shared.currentAccount else {
            logger.error("Migration account not found")
            completionClosure(.failure(MigrationServiceError.startMigrationFail))
            return
        }
        guard let engine = engine else {
            logger.error("Migration connection not found")
            completionClosure(.failure(MigrationServiceError.startMigrationFail))
            return
        }
        guard let runtimeRegistry = runtimeRegistry else {
            logger.error("Migration runtime registry not found")
            completionClosure(.failure(MigrationServiceError.startMigrationFail))
            return
        }
        cancelFinalityRecoveryIfAccountChanged(to: account.address)
        let statusEngine = Sora2BoundedHTTPJSONRPCEngine.wrapping(engine)
        guard !resumePendingMigrationIfNeeded(
            account: account,
            engine: statusEngine,
            runtimeRegistry: runtimeRegistry,
            completion: completionClosure
        ) else {
            return
        }
        guard let did = createIrohaDid(for: account.address) else {
            logger.error("IrohaKeyPair failed")
            completionClosure(.failure(MigrationServiceError.startMigrationFail))
            return
        }
        guard let eligibilityToken = eligibilityGate.begin(
            accountAddress: account.address
        ) else {
            completionClosure(.failure(MigrationServiceError.startMigrationFail))
            return
        }
        do {
            _ = try statusEngine.callMethod(
                RPCMethod.needsMigration,
                params: [did],
                completion: { [weak self] (result: Result<Bool, Error>) in
                    guard let self else { return }
                    DispatchQueue.main.async {
                        guard
                            SelectedWalletSettings.shared.currentAccount?
                                .address == account.address
                        else {
                            _ = self.eligibilityGate.consume(
                                token: eligibilityToken,
                                accountAddress: account.address
                            )
                            completionClosure(
                                .failure(
                                    MigrationServiceError.startMigrationFail
                                )
                            )
                            return
                        }
                        switch result {
                        case let .success(migrationNeeded):
                            guard migrationNeeded else {
                                guard self.eligibilityGate
                                    .consumeAwaitingEligibility(
                                        token: eligibilityToken,
                                        accountAddress: account.address
                                    )
                                else {
                                    return
                                }
                                self.migrationSuccess(
                                    accountAddress: account.address
                                )
                                completionClosure(.success(""))
                                return
                            }
                            guard self.eligibilityGate.authorizeForSigning(
                                token: eligibilityToken,
                                accountAddress: account.address
                            ) else {
                                return
                            }
                            self.submitMigration(
                                account: account,
                                expectedDid: did,
                                eligibilityToken: eligibilityToken,
                                engine: engine,
                                runtimeRegistry: runtimeRegistry,
                                completion: completionClosure
                            )
                        case .failure:
                            guard self.eligibilityGate
                                .consumeAwaitingEligibility(
                                    token: eligibilityToken,
                                    accountAddress: account.address
                                )
                            else {
                                return
                            }
                            self.logger.error(
                                "Migration pre-sign eligibility failed"
                            )
                            completionClosure(
                                .failure(
                                    MigrationServiceError.startMigrationFail
                                )
                            )
                        }
                    }
                }
            )
        } catch {
            _ = eligibilityGate.consume(
                token: eligibilityToken,
                accountAddress: account.address
            )
            logger.error("Migration pre-sign eligibility failed")
            completionClosure(.failure(MigrationServiceError.startMigrationFail))
        }
    }

    private func submitMigration(
        account: AccountItem,
        expectedDid: String,
        eligibilityToken: UUID,
        engine: JSONRPCEngine,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        completion completionClosure: @escaping MigrationResultClosure
    ) {
        guard
            eligibilityGate.validateSigningAuthorization(
                token: eligibilityToken,
                accountAddress: account.address
            ),
            SelectedWalletSettings.shared.currentAccount?.address ==
                account.address,
            let irohaKeyPair = createIrohaKeyPair(for: account.address),
            let did = createDid(from: irohaKeyPair),
            did == expectedDid
        else {
            _ = eligibilityGate.consume(
                token: eligibilityToken,
                accountAddress: account.address
            )
            logger.error("Migration identity changed before signing")
            completionClosure(.failure(MigrationServiceError.startMigrationFail))
            return
        }

        let signer = SigningWrapper(keystore: keystore, account: account)
        let irohaSigner = IRSigningDecorator(
            keystore: keystore,
            identifier: "iroha"
        )
        let extrinsicService = ExtrinsicService(
            address: account.address,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtimeRegistry,
            engine: engine,
            operationManager: operationManager
        )
        let irohaKey = irohaKeyPair.publicKey().rawData().toHex()
        guard
            let message = (did + irohaKey).data(using: .utf8),
            let data = try? NSData(data: message).sha3(
                IRSha3Variant.variant256
            ),
            let signature = try? irohaSigner.sign(
                data,
                privateKey: irohaKeyPair.privateKey()
            )
        else {
            _ = eligibilityGate.consume(
                token: eligibilityToken,
                accountAddress: account.address
            )
            logger.error("Migration signing fail")
            completionClosure(.failure(MigrationServiceError.startMigrationFail))
            return
        }

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()
            let migrateCall = try callFactory.migrate(
                irohaAddress: did,
                irohaKey: irohaKey,
                signature: signature.rawData().toHex()
            )
            return try builder.adding(call: migrateCall)
        }
        extrinsicService.submit(
            closure,
            signer: signer,
            lifecycleLease: nil,
            purpose: .legacyMigration,
            preSigningValidation: {
                guard
                    self.eligibilityGate.validateSigningAuthorization(
                        token: eligibilityToken,
                        accountAddress: account.address
                    ),
                    SelectedWalletSettings.shared.currentAccount?
                        .address == account.address
                else {
                    throw MigrationServiceError.startMigrationFail
                }
            },
            runningIn: .main
        ) { [weak self] result, callbackHash, _ in
            guard let self else { return }
            _ = self.eligibilityGate.consume(
                token: eligibilityToken,
                accountAddress: account.address
            )
            let localHash: String
            switch result {
            case let .success(returnedHash):
                guard
                    let normalized = Sora2PendingSubmissionStore
                        .normalizedHash(returnedHash),
                    let callbackHash,
                    Sora2PendingSubmissionStore
                        .normalizedHash(callbackHash) == normalized
                else {
                    self.logger.error(
                        "Migration submission hash validation failed"
                    )
                    return
                }
                localHash = normalized
            case let .failure(error):
                guard
                    let transportError =
                        error as? PreparedExtrinsicTransportError,
                    let ambiguousHash =
                        transportError.submissionUnknownLocalHash,
                    let callbackHash,
                    Sora2PendingSubmissionStore
                        .normalizedHash(callbackHash) == ambiguousHash
                else {
                    self.logger.error("Migration failed before transport")
                    completionClosure(.failure(error))
                    return
                }
                localHash = ambiguousHash
            }
            self.startMigrationFinalityRecovery(
                accountAddress: account.address,
                transactionHash: localHash,
                engine: engine,
                runtimeRegistry: runtimeRegistry,
                completion: completionClosure
            )
        }
    }

    /// A purpose-tagged generic journal row is the durable feature state for
    /// legacy migration. It prevents a relaunch or repeated tap from signing a
    /// second migration while the first exact hash is still ambiguous.
    private func resumePendingMigrationIfNeeded(
        account: AccountItem,
        engine: JSONRPCEngine,
        runtimeRegistry: RuntimeCodingServiceProtocol?,
        completion: MigrationResultClosure?
    ) -> Bool {
        let values: [Sora2PendingSubmission]
        do {
            values = try Sora2PendingSubmissionStore().all()
        } catch {
            logger.error("Migration pending journal is unavailable")
            failAttachedMigrationRequest(completion)
            return true
        }
        let accountValues = values.filter { $0.account == account.address }
        let migrationValues = accountValues.filter {
            $0.purpose == .legacyMigration
        }
        // Every purpose-tagged migration written by this release carries the
        // exact runtime/wallet/era witness. A malformed, downgraded, or
        // partially rewritten tagged row is not permission to submit again.
        if migrationValues.contains(where: {
            $0.recoveryContext == nil ||
                $0.state == .stagedBeforeTransport
        }) {
            logger.error("Migration recovery witness is incomplete")
            failAttachedMigrationRequest(completion)
            return true
        }
        if migrationValues.contains(where: {
            $0.terminalResolution?.kind == .finalizedSuccess
        }) {
            migrationSuccess(accountAddress: account.address)
            completion?(.success(""))
            return true
        }
        let unresolvedMigration = migrationValues.filter {
            !$0.isPrunable
        }
        guard unresolvedMigration.count <= 1 else {
            logger.error("Multiple unresolved migration submissions")
            failAttachedMigrationRequest(completion)
            return true
        }
        if let pending = unresolvedMigration.first {
            guard let runtimeRegistry else {
                failAttachedMigrationRequest(completion)
                return true
            }
            startMigrationFinalityRecovery(
                accountAddress: account.address,
                transactionHash: pending.extrinsicHash,
                engine: engine,
                runtimeRegistry: runtimeRegistry,
                completion: completion
            )
            return true
        }
        // A pre-purpose journal cannot prove whether its exact unresolved
        // SORA2 hash belonged to this feature. Fail closed instead of showing
        // a retry action that could duplicate an older migration.
        if accountValues.contains(where: {
            $0.purpose == nil && !$0.isPrunable
        }) {
            logger.error("Legacy ambiguous submission blocks migration")
            failAttachedMigrationRequest(completion)
            return true
        }
        return false
    }

    private func startMigrationFinalityRecovery(
        accountAddress: String,
        transactionHash: String,
        engine: JSONRPCEngine,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        completion: MigrationResultClosure?
    ) {
        guard
            let canonicalHash = Sora2PendingSubmissionStore
                .normalizedHash(transactionHash)
        else {
            failAttachedMigrationRequest(completion)
            return
        }
        finalityLock.lock()
        if let current = finalityRecovery {
            let matches = current.matches(
                accountAddress: accountAddress,
                transactionHash: canonicalHash
            )
            finalityLock.unlock()
            if matches, let completion {
                if !current.attach(completion) {
                    DispatchQueue.main.async {
                        completion(
                            .failure(
                                MigrationServiceError.startMigrationFail
                            )
                        )
                    }
                }
            } else if !matches, let completion {
                DispatchQueue.main.async {
                    completion(
                        .failure(MigrationServiceError.startMigrationFail)
                    )
                }
            }
            return
        }
        let recovery = MigrationFinalityRecoveryHandle(
            accountAddress: accountAddress,
            transactionHash: canonicalHash,
            completion: completion
        )
        finalityRecovery = recovery
        finalityLock.unlock()

        let task = Task { [weak self, recovery] in
            var outcome: MigrationFinalityOutcome?
            defer {
                let attachedCompletion = recovery.finish()
                self?.clearFinalityRecovery(recovery)
                if let self, let outcome {
                    DispatchQueue.main.async {
                        guard
                            SelectedWalletSettings.shared.currentAccount?
                                .address == accountAddress
                        else {
                            return
                        }
                        switch outcome {
                        case .finalizedSuccess:
                            self.migrationSuccess(
                                accountAddress: accountAddress
                            )
                            attachedCompletion?(.success(""))
                        case .retrySafeFailure:
                            if let attachedCompletion {
                                attachedCompletion(
                                    .failure(
                                        MigrationServiceError
                                            .confirmMigrationFail
                                    )
                                )
                            } else {
                                self.decideMigration()
                            }
                        case .recoveryUnavailable:
                            attachedCompletion?(
                                .failure(
                                    MigrationServiceError.startMigrationFail
                                )
                            )
                        }
                    }
                }
            }
            guard let self else { return }
            let store: Sora2PendingSubmissionStore
            do {
                store = try Sora2PendingSubmissionStore()
            } catch {
                self.logger.error("Migration recovery journal unavailable")
                outcome = .recoveryUnavailable
                return
            }
            let reconciler = Sora2PendingSubmissionReconciler(
                store: store,
                engine: engine,
                runtimeService: runtimeRegistry
            )
            while !Task.isCancelled {
                do {
                    try await reconciler.reconcileStatusOnly()
                } catch is CancellationError {
                    return
                } catch {
                    // Every status request has its own finite transport bound.
                    // Offline/unready state remains pending for the next pass.
                    self.logger.error("Migration finality check deferred")
                }

                let matches: [Sora2PendingSubmission]
                do {
                    matches = try store.all().filter {
                        $0.account == accountAddress &&
                            $0.extrinsicHash == canonicalHash &&
                            $0.purpose == .legacyMigration
                    }
                } catch {
                    self.logger.error("Migration recovery journal unreadable")
                    outcome = .recoveryUnavailable
                    return
                }
                guard matches.count == 1 else {
                    // Missing/duplicate durable evidence is not permission to
                    // ask the user to retry.
                    self.logger.error("Migration recovery witness mismatch")
                    outcome = .recoveryUnavailable
                    return
                }
                if let terminal = matches[0].terminalResolution {
                    switch terminal.kind {
                    case .finalizedSuccess:
                        outcome = .finalizedSuccess
                    case .finalizedFailure, .expiredNotIncluded:
                        outcome = .retrySafeFailure
                    }
                    return
                }
                do {
                    try await Task.sleep(
                        nanoseconds: Self.finalityRetryNanoseconds
                    )
                } catch {
                    return
                }
            }
        }
        recovery.install(task)
    }

    private func failAttachedMigrationRequest(
        _ completion: MigrationResultClosure?
    ) {
        guard let completion else {
            return
        }
        DispatchQueue.main.async {
            completion(.failure(MigrationServiceError.startMigrationFail))
        }
    }

    private func cancelFinalityRecoveryIfAccountChanged(
        to accountAddress: String
    ) {
        finalityLock.lock()
        let recovery = finalityRecovery
        if recovery?.accountAddress != accountAddress {
            finalityRecovery = nil
        }
        finalityLock.unlock()
        if recovery?.accountAddress != accountAddress {
            recovery?.cancel()
        }
    }

    private func clearFinalityRecovery(
        _ recovery: MigrationFinalityRecoveryHandle
    ) {
        finalityLock.lock()
        if finalityRecovery === recovery {
            finalityRecovery = nil
        }
        finalityLock.unlock()
    }

    private func createIrohaKeyPair(
        for accountAddress: String
    ) -> IRCryptoKeypairProtocol? {
        if let entropy = try? keystore.fetchEntropyForAddress(accountAddress),
            let mnemonic = try? IRMnemonicCreator().mnemonic(fromEntropy: entropy),
            let irohaKey = try? IRKeypairFacade().deriveKeypair(from: mnemonic.toString()) {
            return irohaKey
        }
        return nil
    }

    private func createIrohaDid(for accountAddress: String) -> String? {
        guard let keyPair = createIrohaKeyPair(for: accountAddress) else {
            return nil
        }
        return createDid(from: keyPair)
    }

    private func createDid(
        from keyPair: IRCryptoKeypairProtocol
    ) -> String? {
        let username = keyPair.publicKey().decentralizedUsername
        guard username.utf8.count == 20 else {
            return nil
        }
        return "did_sora_\(username)@sora"
    }
}
