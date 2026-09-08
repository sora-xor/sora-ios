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
import RobinHood
import SoraKeystore
import SSFUtils
import IrohaCrypto

typealias RuntimeServiceProtocol = RuntimeRegistryServiceProtocol & RuntimeCodingServiceProtocol

/// A retry can fail for a different reason than the original recovery marker.
/// Keep that new outcome separately: it is diagnostic evidence, not permission
/// to clear the marker. Only fixed codes and numeric framework status are stored.
struct WalletStartupDiagnostic: Codable, Equatable {
    enum Phase: String, Codable {
        case startupRecovery = "startup_recovery"
        case journalRecovery = "journal_recovery"
        case databaseMigration = "database_migration"
        case databaseInventory = "database_inventory"
        case networkSnapshot = "network_snapshot"
        case selectedAccount = "selected_account"
        case networkBootstrap = "network_bootstrap"
    }

    enum Cause: String, Codable {
        case unexpected = "unexpected_failure"
        case unknownStore = "unknown_store_version"
        case unavailableModel = "unavailable_model"
        case incompleteMigration = "incomplete_migration_path"
        case interruptedMigration = "interrupted_migration"
        case missingStore = "missing_wallet_store"
        case missingSecret = "missing_wallet_secret"
        case emptySecret = "empty_wallet_secret"
        case insufficientStorage = "insufficient_storage"
        case backupVerification = "backup_verification_failed"
        case inventoryMismatch = "account_inventory_mismatch"
        case selectionMismatch = "selected_account_mismatch"
        case keychainIdentifier = "keychain_identifier"
        case keychainMissing = "keychain_missing"
        case keychainDuplicate = "keychain_duplicate"
        case keychainResult = "keychain_result"
        case keychainSystem = "keychain_system"
        case duplicateAccounts = "duplicate_accounts"
        case multipleSelections = "multiple_selections"
        case missingSelection = "missing_selection"
        case legacyUpgradeProof = "legacy_upgrade_proof"
        case invalidMnemonic = "invalid_mnemonic"
        case invalidDerivation = "invalid_derivation"
        case derivationFailed = "derivation_failed"
        case invalidPrivateKey = "invalid_private_key"
        case snapshotVerification = "snapshot_verification"
        case missingSnapshot = "missing_snapshot"
        case lifecycleBusy = "lifecycle_busy"
        case recoveryRequired = "recovery_required"
        case legacyIdentityMismatch = "legacy_identity_mismatch"
        case removalMismatch = "removal_mismatch"
        case decoding = "decoding_failed"
        case encoding = "encoding_failed"
        case fileProtection = "file_protection_unavailable"
        case durableTarget = "durable_file_target"
        case durableCommit = "durable_file_commit"
        case migrationNamespace = "migration_namespace"
        case cocoa, posix, osstatus, url
    }

    private static let settingsKey = SettingsKey.walletStartupDiagnostic.rawValue
    let phase: Phase
    let cause: Cause
    let systemCode: Int?
    private let markerGeneration: String?

    var summary: String {
        let suffix = systemCode.map { " (\($0))" } ?? ""
        return "Latest verification: \(phase.rawValue) / \(cause.rawValue)\(suffix)"
    }

    private static func classify(_ error: Error) -> (Cause, Int?) {
        if let error = error as? UserStorageMigrationError {
            return (Cause(rawValue: error.privacySafeOutcomeCode) ?? .unexpected, nil)
        }
        if let error = error as? KeystoreSystemError {
            return (.keychainSystem, Int(error.status))
        }
        if let error = error as? KeystoreError {
            switch error {
            case .invalidIdentifierFormat: return (.keychainIdentifier, nil)
            case .noKeyFound: return (.keychainMissing, nil)
            case .duplicatedItem: return (.keychainDuplicate, nil)
            case .unexpectedFail: return (.keychainResult, nil)
            }
        }
        if let error = error as? SelectedWalletSettingsError {
            switch error {
            case .duplicateAccountIdentifiers: return (.duplicateAccounts, nil)
            case .multipleSelectedAccounts: return (.multipleSelections, nil)
            case .missingSelectedAccount: return (.missingSelection, nil)
            }
        }
        if let error = error as? WalletIntegrityError {
            switch error {
            case .selectedAccountSecretMissing: return (.missingSecret, nil)
            case .selectedAccountMissing: return (.missingSelection, nil)
            case .legacyWalletUpgradeVerificationFailed: return (.legacyUpgradeProof, nil)
            }
        }
        if let error = error as? WalletNetworkMigrationError {
            switch error {
            case .invalidMnemonic: return (.invalidMnemonic, nil)
            case .invalidDerivationPath, .nonHardenedDerivationComponent,
                 .invalidDerivationIndex: return (.invalidDerivation, nil)
            case .keyDerivationFailed: return (.derivationFailed, nil)
            case .invalidPrivateKey: return (.invalidPrivateKey, nil)
            case .snapshotVerificationFailed: return (.snapshotVerification, nil)
            case .missingSnapshot: return (.missingSnapshot, nil)
            case .missingSelectedWallet: return (.missingSelection, nil)
            case .lifecycleMutationBusy: return (.lifecycleBusy, nil)
            case .walletRecoveryRequired: return (.recoveryRequired, nil)
            case .legacyIdentityMismatch: return (.legacyIdentityMismatch, nil)
            case .explicitRemovalTargetMissing, .explicitRemovalInventoryMismatch,
                 .explicitRemovalSelectionMismatch: return (.removalMismatch, nil)
            }
        }
        if error is DecodingError { return (.decoding, nil) }
        if error is EncodingError { return (.encoding, nil) }
        if error is FileProtectionMetadata.Failure { return (.fileProtection, nil) }
        if error is WalletMigrationSafetyNamespaceAdmission.Failure { return (.migrationNamespace, nil) }
        if let error = error as? DurableFileWriter.Failure {
            switch error {
            case .invalidTarget: return (.durableTarget, nil)
            case .fileSystemFailure: return (.durableCommit, nil)
            }
        }
        let systemError = error as NSError
        let family: Cause
        switch systemError.domain {
        case NSCocoaErrorDomain: family = .cocoa
        case NSPOSIXErrorDomain: family = .posix
        case NSOSStatusErrorDomain: family = .osstatus
        case NSURLErrorDomain: family = .url
        default: return (.unexpected, nil)
        }
        return (family, systemError.code)
    }

    static func record(_ error: Error, phase: Phase, settings: SettingsManagerProtocol) {
        let detail = error as? WalletStartupCheckFailure
        let (cause, code) = classify(detail?.underlying ?? error)
        WalletMigrationRecoveryMarker.synchronized {
            let marker = WalletMigrationRecoveryMarker.capture(settings)
            guard marker.required else { return }
            let value = Self(phase: detail?.phase ?? phase, cause: cause,
                systemCode: code, markerGeneration: marker.generation)
            guard let data = try? JSONEncoder().encode(value) else { return }
            settings.set(value: String(decoding: data, as: UTF8.self), for: settingsKey)
            Logger.shared.error(value.summary)
        }
    }

    static func current(_ settings: SettingsManagerProtocol) -> Self? {
        WalletMigrationRecoveryMarker.synchronized {
            let marker = WalletMigrationRecoveryMarker.capture(settings)
            guard marker.required,
                  let stored = settings.string(for: settingsKey), stored.utf8.count <= 1_024,
                  let value = try? JSONDecoder().decode(Self.self, from: Data(stored.utf8)),
                  value.markerGeneration == marker.generation else { return nil }
            return value
        }
    }

    static func check<T>(_ phase: Phase, _ body: () throws -> T) throws -> T {
        do { return try body() }
        catch let failure as WalletStartupCheckFailure { throw failure }
        catch { throw WalletStartupCheckFailure(phase: phase, underlying: error) }
    }
}

private struct WalletStartupCheckFailure: Error {
    let phase: WalletStartupDiagnostic.Phase
    let underlying: Error
}

enum WalletStorageStartupOutcome: Equatable {
    case ready
    case needsStorageSpace
    case recoveryRequired
}

enum WalletStorageStartup {
    static func run(
        settings: SettingsManagerProtocol,
        accountCommitRecovery: (() throws -> Void)? = nil,
        migration: () throws -> Void
    ) -> WalletStorageStartupOutcome {
        do {
            try accountCommitRecovery?()
        } catch {
            if !settings.walletMigrationRecoveryRequired {
                settings.setWalletMigrationRecovery(
                    reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error),
                    preservingExistingReason: true
                )
            }
            WalletStartupDiagnostic.record(error, phase: .startupRecovery, settings: settings)
            return .recoveryRequired
        }
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        guard !marker.required || marker.isDatabaseInterruption else {
            return .recoveryRequired
        }
        do {
            try migration()
            return settings.walletMigrationRecoveryRequired
                ? .recoveryRequired : .ready
        } catch {
            // This typed error is raised by the capacity preflight before
            // checkpointing, backup creation or store replacement. Do not
            // turn a full disk into an irreversible integrity-recovery latch.
            // A marker raised by another check still takes precedence.
            if case UserStorageMigrationError.insufficientStorage = error,
               !settings.walletMigrationRecoveryRequired {
                return .needsStorageSpace
            }
            if !settings.walletMigrationRecoveryRequired {
                settings.setWalletMigrationRecovery(
                    reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error),
                    preservingExistingReason: true
                )
            }
            WalletStartupDiagnostic.record(error, phase: .databaseMigration, settings: settings)
            Logger.shared.error(
                "Wallet startup outcome: \(UserStorageMigrationError.privacySafeOutcomeCode(for: error))"
            )
            return .recoveryRequired
        }
    }
}

/// Older builds latched any unexpected framework error as a permanent wallet
/// failure. Retry only that exact marker, retaining the ordinary operation gate
/// until the complete installed account inventory and network keys are proven.
enum WalletStartupVerificationRecovery {
    @discardableResult
    static func recoverIfNeeded(
        storeURL: URL, modelDirectory: String,
        keystore: KeystoreProtocol, settings: SettingsManagerProtocol,
        baseURL: URL? = nil,
        lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
        checkpoint: () throws -> Void = {}
    ) throws -> Bool {
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        guard marker.isStartupVerificationFailure else { return false }
        let lease = lifecycleCoordinator.acquire()
        defer { lease.release() }
        try marker.requireUnchangedForStartupVerification(settings)
        let hasDatabaseJournal = {
            WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: storeURL)
        }
        let hasAccountJournal = {
            try !WalletAccountCommitJournalStore(baseURL: baseURL).unresolved().isEmpty
        }
        // A generic marker may have been latched after a recoverable transaction
        // was written. Give that transaction its existing full recovery proof
        // while the generic marker and ordinary wallet gate remain required.
        try WalletStartupDiagnostic.check(.journalRecovery) {
            let accountPending = try hasAccountJournal()
            guard !hasDatabaseJournal() || !accountPending else {
                throw UserStorageMigrationError.interruptedMigration
            }
            let journalGate = WalletRecoveryCapabilityGate(settings: settings,
                unresolvedMigrationJournal: { false },
                unresolvedWalletCommitJournal: { false },
                startupVerificationMarker: marker)
            if try hasAccountJournal() {
                try LegacyWalletAccountCommitRecovery.recoverIfNeeded(
                    storeURL: storeURL, modelDirectory: modelDirectory,
                    keystore: keystore, settings: settings, baseURL: baseURL,
                    lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: journalGate),
                    recoveryGate: journalGate, startupVerificationMarker: marker)
            }
            if hasDatabaseJournal() {
                let journalStore = try WalletNetworkStore(baseURL: baseURL, recoveryGate: journalGate)
                let database = UserStorageMigrator(targetVersion: UserStorageParams.modelVersion,
                    storeURL: storeURL, modelDirectory: modelDirectory, keystore: keystore,
                    settings: settings, fileManager: .default, recoveryGate: journalGate,
                    loadWalletNetworkSnapshot: { try journalStore.load() })
                try database.resumeForStartupVerification(marker: marker)
            }
        }
        guard !hasDatabaseJournal(), try !hasAccountJournal() else {
            throw UserStorageMigrationError.interruptedMigration
        }
        let gate = WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: hasDatabaseJournal,
            unresolvedWalletCommitJournal: hasAccountJournal,
            startupVerificationMarker: marker)
        try gate.requireMutableWalletAccess()
        let store = try WalletNetworkStore(baseURL: baseURL, recoveryGate: gate)
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: storeURL.path) {
            let retainedPaths = [storeURL, URL(fileURLWithPath: storeURL.path + "-wal"),
                URL(fileURLWithPath: storeURL.path + "-shm"),
                storeURL.deletingLastPathComponent().appendingPathComponent("WalletMigrationSafety")]
            guard !retainedPaths.contains(where: { (try? fileManager.attributesOfItem(atPath: $0.path)) != nil }),
                  try LegacyWalletUpgradePolicy.shouldDeferStorageMigration(storeExists: false,
                    keystore: keystore, hasWatchOnlyWallet: settings.hasRetainedWatchOnlyWallet(),
                    snapshot: store.load())
            else { throw UserStorageMigrationError.missingWalletStore }
            var entropy = try keystore.fetchKey(for: KeystoreTag.legacyEntropy.rawValue)
            defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
            let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy)
            guard WalletMnemonicWordPolicy.retainedSoraWordCounts.contains(mnemonic.allWords().count) else {
                throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed
            }
            _ = try LegacyWalletUpgradeDisplayNameResolver.resolve(settings: settings, keystore: keystore)
            // The existing explicit legacy-upgrade flow creates the first account.
        } else {
            let database = UserStorageMigrator(targetVersion: UserStorageParams.modelVersion,
                storeURL: storeURL, modelDirectory: modelDirectory, keystore: keystore,
                settings: settings, fileManager: fileManager, recoveryGate: gate,
                loadWalletNetworkSnapshot: { try store.load() })
            try WalletStartupDiagnostic.check(.databaseMigration) {
                try database.performMigration()
            }
            let accounts = try WalletStartupDiagnostic.check(.databaseInventory) {
                try database.verifiedCurrentAccounts()
            }
            let selected = try SelectedWalletSettings.resolveSelection(accounts: accounts,
                legacySelectedAddress: settings.value(of: AccountItem.self,
                    for: SettingsKey.selectedAccount.rawValue)?.identifier)
            guard !accounts.isEmpty, let selected else {
                throw UserStorageMigrationError.selectedAccountMismatch
            }
            // The outer lease excludes normal lifecycle operations. The private
            // coordinator admits only verification bound to this exact marker.
            let verifier = WalletNetworkModelMigrator(keystore: keystore, store: store,
                settings: settings, lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: gate),
                recoveryGate: gate)
            let expected = try WalletStartupDiagnostic.check(.networkSnapshot) {
                try verifier.verifiedSnapshot(accounts: accounts, selectedAddress: selected.address)
            }
            let current = try store.load()
            if current?.wallets != expected.wallets || current?.accounts != expected.accounts ||
                current?.selectedWalletId != expected.selectedWalletId {
                try verifier.migrate(accounts: accounts, selectedAddress: selected.address)
            }
            let finalAccounts = try database.verifiedCurrentAccounts()
            guard Set(finalAccounts.map(\.address)) == Set(accounts.map(\.address)),
                  finalAccounts.allSatisfy({ account in accounts.contains(account) })
            else { throw UserStorageMigrationError.accountInventoryMismatch }
            let verified = try verifier.verifiedSnapshot(accounts: finalAccounts, selectedAddress: selected.address)
            guard let active = try store.load(), active.wallets == verified.wallets,
                  active.accounts == verified.accounts, active.selectedWalletId == verified.selectedWalletId
            else { throw WalletNetworkMigrationError.snapshotVerificationFailed }
        }
        try checkpoint()
        guard !hasDatabaseJournal(), try !hasAccountJournal() else {
            throw UserStorageMigrationError.interruptedMigration
        }
        try gate.requireMutableWalletAccess()
        try marker.clearAfterVerifiedStartup(settings)
        return true
    }
}

final class SplashInteractor: SplashInteractorProtocol {
    weak var presenter: SplashPresenterProtocol!
    let settings: SettingsManagerProtocol
    let socketService: WebSocketServiceProtocol
    let configService: ConfigServiceProtocol
    let reachabilityManager: ReachabilityManagerProtocol? = ReachabilityManager.shared
    private let migrationStateLock = NSLock()
    private var didStartStorageMigration = false
    private var isAwaitingStorageRetry = false
    private let storageMigrationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "co.jp.soramitsu.sora.storage-migration"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    init(settings: SettingsManagerProtocol,
         socketService: WebSocketServiceProtocol,
         configService: ConfigServiceProtocol) {
        self.settings = settings
        self.socketService = socketService
        self.configService = configService
    }

    func setup() {
        configService.setupConfig { [weak self] in
            self?.socketService.setup()
            self?.loadGenesis()
        }
    }

    func retryStorageMigration() {
        migrationStateLock.lock()
        guard isAwaitingStorageRetry else {
            migrationStateLock.unlock()
            return
        }
        isAwaitingStorageRetry = false
        migrationStateLock.unlock()
        storageMigrationQueue.addOperation { [weak self] in
            self?.performStorageMigration()
        }
    }

    private func loadGenesis() {
        guard reachabilityManager?.isReachable ?? false else {
            loadAssetsInfo(chainId: nil)
            return
        }

        let provider = GenesisProvider(engine: socketService.connection!)
        provider.load(completion: { [weak self] genesis in
            self?.didLoadGenesis(genesis)
        })
    }

    private func didLoadGenesis(_ genesis: String?) {
        if let genesis = genesis {
            self.settings.set(value: genesis, for: SettingsKey.externalGenesis.rawValue)
            Logger.shared.info("Runtime update gen: " + genesis)
        }
        loadAssetsInfo(chainId: genesis)
    }

    private func loadAssetsInfo(chainId: String?) {
        guard reachabilityManager?.isReachable ?? false else {
            didLoadAssetsInfo([])
            return
        }
        
        let provider = AssetsInfoProvider(engine: socketService.connection!, storageKeyFactory: StorageKeyFactory(), chainId: chainId)
        provider.load { [weak self] assetsInfo in
            self?.didLoadAssetsInfo(assetsInfo)
        }
    }

    private func didLoadAssetsInfo(_ assetsInfo: [AssetInfo]) {
        Task {
            AssetManager.networkAssets = assetsInfo

            // Fiat prices and market-cap data are display-only and every consumer already loads
            // them lazily through getPriceInfo(for:). A slow PI request must not hold wallet
            // storage migration, recovery checks, or navigation on the splash screen.

            socketService.throttle()

            await MainActor.run {
                self.startChain()
            }
        }
    }

    @MainActor
    private func startChain() {
        migrationStateLock.lock()
        guard !didStartStorageMigration else {
            migrationStateLock.unlock()
            return
        }
        didStartStorageMigration = true
        migrationStateLock.unlock()

        NexusTransactionRuntime.shared.prepareForWalletStorageMigration()
        Sora2PendingSubmissionRecoveryRuntime.shared
            .prepareForWalletStorageMigration()

        storageMigrationQueue.addOperation { [weak self] in
            self?.performStorageMigration()
        }
    }

    private func performStorageMigration() {
        let keychain = Keychain()
        let dbMigrator = UserStorageMigrator(
            targetVersion: UserStorageParams.modelVersion,
            storeURL: UserStorageParams.storageURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keychain,
            settings: settings,
            fileManager: FileManager.default
        )
//it should not be here, but since we're trying to limit chain sync to the splash screen, we need working settings and have to migrate them because robinhood does not support lightweight migration (yet?)
        var deferredForLegacyUpgrade = false
        let outcome = WalletStorageStartup.run(settings: settings, accountCommitRecovery: {
            try WalletStartupVerificationRecovery.recoverIfNeeded(
                storeURL: UserStorageParams.storageURL,
                modelDirectory: UserStorageParams.modelDirectory,
                keystore: keychain,
                settings: self.settings
            )
            try LegacyWalletAccountCommitRecovery.recoverIfNeeded(
                storeURL: UserStorageParams.storageURL,
                modelDirectory: UserStorageParams.modelDirectory,
                keystore: keychain,
                settings: self.settings
            )
        }) {
            let unresolvedCommits =
                try WalletAccountCommitJournalStore().unresolved()
            guard unresolvedCommits.isEmpty else {
                throw UserStorageMigrationError.interruptedMigration
            }
            if !settings.walletMigrationRecoveryRequired,
               try LegacyWalletUpgradePolicy.shouldDeferStorageMigration(
                storeExists: FileManager.default.fileExists(
                    atPath: UserStorageParams.storageURL.path
                ),
                keystore: keychain,
                hasWatchOnlyWallet: settings.hasRetainedWatchOnlyWallet(),
                snapshot: try WalletNetworkStore().load()
            ) {
                // This pre-account-model state has retained legacy entropy
                // and, in 1.x, its verified Iroha key. Do not create an
                // empty replacement store; Root presents the explicit,
                // journaled upgrade confirmation and verifies the resulting
                // SORA identity while retaining the original Keychain entry.
                deferredForLegacyUpgrade = true
                return
            }
            try dbMigrator.migrateAtStartup()
        }

        switch outcome {
        case .needsStorageSpace:
            migrationStateLock.lock()
            isAwaitingStorageRetry = true
            migrationStateLock.unlock()
            DispatchQueue.main.async { [weak self] in
                self?.presenter.storageSpaceRequired()
            }
            return
        case .recoveryRequired:
            completeSplashOnMain()
            return
        case .ready:
            break
        }

        if deferredForLegacyUpgrade {
            completeSplashOnMain()
            return
        }

        guard !settings.walletMigrationRecoveryRequired else {
            completeSplashOnMain()
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.setupSelectedWalletAfterMigration()
        }
    }

    private func setupSelectedWalletAfterMigration() {
        let logger = Logger.shared
        let selectedSettings = SelectedWalletSettings.shared
        selectedSettings.setup(runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(maybeAccount):
                self?.bootstrapWalletNetworks(selectedAccount: maybeAccount)
            case let .failure(error):
                let outcome = UserStorageMigrationError
                    .privacySafeOutcomeCode(for: error)
                logger.error(
                    "Selected account setup outcome: \(outcome)"
                )
                self?.settings.setWalletMigrationRecovery(
                    reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
                )
                if let self {
                    WalletStartupDiagnostic.record(error, phase: .selectedAccount, settings: self.settings)
                }
                self?.presenter.setupComplete()
            }
        }
    }

    private func completeSplashOnMain() {
        DispatchQueue.main.async { [weak self] in
            self?.presenter.setupComplete()
        }
    }

    private func bootstrapWalletNetworks(selectedAccount: AccountItem?) {
        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository(
                filter: nil,
                sortDescriptors: [NSSortDescriptor.accountsByOrder],
                mapper: AnyCoreDataMapper(AccountItemMapper())
            )
        let operation = repository.fetchAllOperation(
            with: RepositoryFetchOptions(
                includesProperties: true,
                includesSubentities: true
            )
        )

        operation.completionBlock = { [weak self] in
            guard let self else {
                return
            }
            do {
                let accounts = try operation.extractNoCancellableResultData()
                let store = try WalletNetworkStore()
                try Self.initializeWalletNetworksIfNeeded(
                    accounts: accounts,
                    selectedAddress: selectedAccount?.address,
                    store: store,
                    keystore: Keychain(),
                    settings: settings
                )

                DispatchQueue.main.async {
                    // The lossless Core Data and wallet-network migrations are
                    // now verified and active. Only now may restart recovery
                    // inspect pending Nexus or SORA2 transactions.
                    NexusTransactionRuntime.shared
                        .markWalletStorageReadyAndResume()
                    Sora2PendingSubmissionRecoveryRuntime.shared
                        .markWalletStorageReadyAndResume()
                    if selectedAccount != nil {
                        ChainRegistryFacade.sharedRegistry.performHotBoot()
                        Logger.shared.debug("Selected wallet restored")
                    } else {
                        ChainRegistryFacade.sharedRegistry.performColdBoot()
                        Logger.shared.debug("No selected account")
                    }
                    self.presenter.setupComplete()
                }
            } catch {
                settings.setWalletMigrationRecovery(
                    reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
                )
                WalletStartupDiagnostic.record(error, phase: .networkBootstrap, settings: settings)
                let outcome = UserStorageMigrationError
                    .privacySafeOutcomeCode(for: error)
                Logger.shared.error(
                    "Wallet network bootstrap outcome: \(outcome)"
                )
                DispatchQueue.main.async {
                    self.presenter.setupComplete()
                }
            }
        }

        OperationManagerFacade.sharedDefaultQueue.addOperation(operation)
    }

    static func initializeWalletNetworksIfNeeded(
        accounts: [AccountItem],
        selectedAddress: String?,
        store: WalletNetworkStore,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol
    ) throws {
        // On a clean install there is no wallet to activate. Creating an empty
        // snapshot here writes a retained-wallet marker before onboarding and
        // makes Root correctly reject the missing selected account. Existing
        // snapshots still receive every migration check; Root independently
        // rejects retained keys/settings when the snapshot is absent.
        if accounts.isEmpty, selectedAddress == nil, try store.load() == nil {
            return
        }
        try WalletNetworkModelMigrator(
            keystore: keystore,
            store: store,
            settings: settings
        ).migrate(accounts: accounts, selectedAddress: selectedAddress)
    }
}
