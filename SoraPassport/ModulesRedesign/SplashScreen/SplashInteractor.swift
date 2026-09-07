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

typealias RuntimeServiceProtocol = RuntimeRegistryServiceProtocol & RuntimeCodingServiceProtocol

enum WalletStorageStartupOutcome: Equatable {
    case ready
    case needsStorageSpace
    case recoveryRequired
}

enum WalletStorageStartup {
    static func run(
        settings: SettingsManagerProtocol,
        migration: () throws -> Void
    ) -> WalletStorageStartupOutcome {
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
            Logger.shared.error(
                "Wallet startup outcome: \(UserStorageMigrationError.privacySafeOutcomeCode(for: error))"
            )
            return .recoveryRequired
        }
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
        let outcome = WalletStorageStartup.run(settings: settings) {
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
