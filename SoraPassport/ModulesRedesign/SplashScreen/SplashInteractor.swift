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

final class SplashInteractor: SplashInteractorProtocol {
    weak var presenter: SplashPresenterProtocol!
    let settings: SettingsManagerProtocol
    let socketService: WebSocketServiceProtocol
    let configService: ConfigServiceProtocol
    let reachabilityManager: ReachabilityManagerProtocol? = ReachabilityManager.shared
    private let migrationStateLock = NSLock()
    private var didStartStorageMigration = false
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
        guard reachabilityManager?.isReachable ?? false,
              let connection = socketService.connection else {
            didLoadAssetsInfo([], chainId: chainId)
            return
        }

        let provider = AssetsInfoProvider(engine: connection, storageKeyFactory: StorageKeyFactory(), chainId: chainId)
        provider.load { [weak self] assetsInfo in
            self?.didLoadAssetsInfo(assetsInfo, chainId: chainId)
        }
    }

    private func didLoadAssetsInfo(_ assetsInfo: [AssetInfo], chainId: String?) {
        if !assetsInfo.isEmpty {
            AssetManager.networkAssets = assetsInfo
            let assetIds = assetsInfo.filter(\.visible).map(\.assetId)
            Task {
                await PriceInfoService.shared.setup(for: assetIds)
            }
        } else {
            Logger.shared.warning(
                "Asset metadata bootstrap is unavailable; continuing with retained chain state"
            )
        }
        socketService.throttle()

        // Wallet migration and unlock must never wait for optional network or
        // price data. Chain services can reconnect after the UI is available.
        DispatchQueue.main.async {
            self.startChain()
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
        // A retained recovery marker means an earlier migration did not reach
        // a fully verified terminal state. Do not inspect/write signing
        // material and do not open or retry the installed store. Restore only
        // its independently retained public identity so the user can
        // authenticate into browse-only mode instead of being trapped on a
        // terminal recovery page.
        guard !settings.walletMigrationRecoveryRequired else {
            completeRecoverySplash(using: keychain)
            return
        }

        // Older production versions keep the selected public account in Settings until
        // Core Data migration completes. Preserve its independently verified signer before
        // any storage migration runs, so a schema/update failure cannot orphan the wallet.
        if let preMigrationAccount = settings.value(
            of: AccountItem.self,
            for: SettingsKey.selectedAccount.rawValue
        ) {
            _ = try? SelectedWalletSettings.reconcileSigningKeyPreservation(
                keystore: keychain,
                account: preMigrationAccount
            )
        }
        let dbMigrator = UserStorageMigrator(
            targetVersion: UserStorageParams.modelVersion,
            storeURL: UserStorageParams.storageURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keychain,
            settings: settings,
            fileManager: FileManager.default
        )
        let logger = Logger.shared
//it should not be here, but since we're trying to limit chain sync to the splash screen, we need working settings and have to migrate them because robinhood does not support lightweight migration (yet?)
        do {
            let unresolvedCommits =
                try WalletAccountCommitJournalStore().unresolved()
            guard unresolvedCommits.isEmpty else {
                throw UserStorageMigrationError.interruptedMigration
            }
            if LegacyWalletUpgradePolicy.shouldDeferStorageMigration(
                storeExists: FileManager.default.fileExists(
                    atPath: UserStorageParams.storageURL.path
                ),
                keyIdentifiers: Set(try keychain.allKeyIdentifiers()),
                hasWatchOnlyWallet: settings.hasRetainedWatchOnlyWallet(),
                snapshot: try WalletNetworkStore().load()
            ) {
                // This exact pre-account-model state has only the retained
                // legacy entropy source. Do not ask Core Data to create an
                // empty replacement store; Root presents the explicit,
                // journaled upgrade confirmation and verifies the resulting
                // SORA identity while retaining the original Keychain entry.
                completeSplashOnMain()
                return
            }
            try WalletLifecycleCoordinator.shared.withExclusiveAccess {
                try dbMigrator.migrate()
            }
        } catch {
            let outcome = UserStorageMigrationError
                .privacySafeOutcomeCode(for: error)
            logger.error(
                "Wallet startup outcome: \(outcome)"
            )
            settings.walletMigrationRecoveryRequired = true
            settings.walletMigrationRecoveryReason = UserStorageMigrationError
                .privacySafeRecoveryDescription(for: error)
            completeRecoverySplash(using: keychain)
            return
        }

        guard !settings.walletMigrationRecoveryRequired else {
            completeRecoverySplash(using: keychain)
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
                self?.settings.walletMigrationRecoveryRequired = true
                self?.settings.walletMigrationRecoveryReason =
                    UserStorageMigrationError
                        .privacySafeRecoveryDescription(for: error)
                self?.completeRecoverySplash(using: Keychain())
            }
        }
    }

    private func completeSplashOnMain(
        retainedAccount: AccountItem? = nil
    ) {
        DispatchQueue.main.async { [weak self] in
            if retainedAccount != nil {
                ChainRegistryFacade.sharedRegistry.performHotBoot()
                Logger.shared.info(
                    "Retained wallet public identity restored for browse-only startup"
                )
            }
            self?.presenter.setupComplete()
        }
    }

    private func completeRecoverySplash(
        using keychain: KeystoreProtocol
    ) {
        let retainedAccount = SelectedWalletSettings
            .activateRetainedAccountForBrowseOnlyRecovery(
                settings: settings,
                keystore: keychain
            )
        completeSplashOnMain(retainedAccount: retainedAccount)
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
                try WalletNetworkModelMigrator(
                    keystore: Keychain(),
                    store: store,
                    settings: settings
                ).migrate(
                    accounts: accounts,
                    selectedAddress: selectedAccount?.address
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
                settings.walletMigrationRecoveryRequired = true
                settings.walletMigrationRecoveryReason = UserStorageMigrationError
                    .privacySafeRecoveryDescription(for: error)
                let outcome = UserStorageMigrationError
                    .privacySafeOutcomeCode(for: error)
                Logger.shared.error(
                    "Wallet network bootstrap outcome: \(outcome)"
                )
                self.completeRecoverySplash(using: Keychain())
            }
        }

        OperationManagerFacade.sharedDefaultQueue.addOperation(operation)
    }
}
