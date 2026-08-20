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

import UIKit
import SoraKeystore
import SoraFoundation
import Then
import SoraUIKit
import IrohaCrypto
import SSFUtils
import SSFCloudStorage
import GoogleSignIn

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static let walletIndex: Int = 0

    @MainActor
    @discardableResult
    static func presentRetainedWalletRecovery(from presentingController: UIViewController?) -> Bool {
        guard
            let recoveryAccount = SelectedWalletSettings.shared.currentAccount,
            SelectedWalletSettings.transactionSigningAvailability(
                settings: SettingsManager.shared,
                keystore: Keychain(),
                account: recoveryAccount,
                attemptRepair: false
            ) != .available
        else {
            return false
        }

        let completion = {
            guard
                let account = SelectedWalletSettings.shared.currentAccount,
                SelectedWalletSettings.transactionSigningAvailability(
                    settings: SettingsManager.shared,
                    keystore: Keychain(),
                    account: account,
                    attemptRepair: false
                ) == .available,
                let mainController = MainTabBarViewFactory.createView()?.controller
            else {
                return
            }

            RootControllerAnimationCoordinator().animateTransition(to: mainController)
        }

        let controller = presentingController
            ?? UIApplication.shared.delegate?.window??.rootViewController
        guard let controller else {
            return false
        }

        let recoveryChooser = RetainedWalletRecoveryViewController(account: recoveryAccount)
        let cloudStorage = CloudStorageService(uiDelegate: recoveryChooser)
        _ = cloudStorage.configureCurrentAccountIfAvailable()
        let storedAssociations = WalletGoogleAccountAssociationStore.shared.associations(
            for: recoveryAccount
        )
        if !storedAssociations.isEmpty {
            recoveryChooser.setGoogleAccountStatus(
                .previouslyUsed(emails: storedAssociations.map(\.email))
            )
        } else if let identity = cloudStorage.currentAccountIdentity {
            recoveryChooser.setGoogleAccountStatus(.available(email: identity.email))
        } else {
            recoveryChooser.setGoogleAccountStatus(.notChecked)
        }
        recoveryChooser.onGoogleBackup = { [weak recoveryChooser] in
            guard let recoveryChooser else { return }
            resolveGoogleAccountForRecovery(
                from: recoveryChooser,
                cloudStorage: cloudStorage,
                recoveryAccount: recoveryAccount,
                completion: completion
            )
        }
        recoveryChooser.onManualSource = { [weak recoveryChooser] sourceType in
            guard let recoveryChooser, recoveryChooser.beginMethodSelection() else { return }
            _ = presentManualRecovery(
                from: recoveryChooser,
                sourceType: sourceType,
                recoveryAccount: recoveryAccount,
                completion: completion
            )
            recoveryChooser.endMethodSelection()
        }
        recoveryChooser.onCancel = { [weak recoveryChooser] in
            recoveryChooser?.dismiss(animated: true)
        }

        let recoveryNavigation = SoraNavigationController(
            rootViewController: recoveryChooser
        )

        return presentAfterDismissingAlert(from: controller) {
            controller.present(recoveryNavigation, animated: true)
        }
    }

    @MainActor
    @discardableResult
    private static func presentManualRecovery(
        from controller: UIViewController,
        sourceType: AccountImportSource,
        recoveryAccount: AccountItem,
        completion: @escaping () -> Void
    ) -> Bool {
        guard let importController = AccountImportViewFactory.createViewForAdding(
            sourceType: sourceType,
            endAddingBlock: completion,
            recoveryAccount: recoveryAccount
        )?.controller else {
            return false
        }

        if let navigationController = controller.navigationController {
            navigationController.pushViewController(importController, animated: true)
        } else {
            controller.present(
                SoraNavigationController(rootViewController: importController),
                animated: true
            )
        }
        return true
    }

    @MainActor
    private static func resolveGoogleAccountForRecovery(
        from controller: RetainedWalletRecoveryViewController,
        cloudStorage: CloudStorageService,
        recoveryAccount: AccountItem,
        completion: @escaping () -> Void
    ) {
        guard controller.beginMethodSelection() else { return }

        let storedAssociations = WalletGoogleAccountAssociationStore.shared.associations(
            for: recoveryAccount
        )
        if !storedAssociations.isEmpty {
            if let identity = cloudStorage.currentAccountIdentity,
               storedAssociations.contains(where: { $0.userID == identity.userID }) {
                controller.endMethodSelection()
                presentGoogleAccountDecision(
                    from: controller,
                    cloudStorage: cloudStorage,
                    identity: identity,
                    recoveryAccount: recoveryAccount,
                    completion: completion
                )
            } else {
                controller.endMethodSelection()
                presentPreviouslyUsedGoogleAccountDecision(
                    from: controller,
                    cloudStorage: cloudStorage,
                    associations: storedAssociations,
                    activeIdentity: cloudStorage.currentAccountIdentity,
                    recoveryAccount: recoveryAccount,
                    completion: completion
                )
            }
            return
        }

        if let identity = cloudStorage.currentAccountIdentity {
            controller.endMethodSelection()
            presentGoogleAccountDecision(
                from: controller,
                cloudStorage: cloudStorage,
                identity: identity,
                recoveryAccount: recoveryAccount,
                completion: completion
            )
            return
        }

        controller.setGoogleAccountStatus(.checking)
        Task { @MainActor [weak controller] in
            guard let controller else { return }

            let identity: CloudStorageAccountIdentity?
            do {
                _ = try await cloudStorage.restorePreviousSignInIfAvailable()
                identity = cloudStorage.currentAccountIdentity
                controller.setGoogleAccountStatus(
                    identity.map { .available(email: $0.email) } ?? .notSaved
                )
            } catch {
                identity = nil
                controller.setGoogleAccountStatus(.unavailable)
            }

            controller.endMethodSelection()
            presentGoogleAccountDecision(
                from: controller,
                cloudStorage: cloudStorage,
                identity: identity,
                recoveryAccount: recoveryAccount,
                completion: completion
            )
        }
    }

    @MainActor
    private static func presentGoogleAccountDecision(
        from controller: RetainedWalletRecoveryViewController,
        cloudStorage: CloudStorageService,
        identity: CloudStorageAccountIdentity?,
        recoveryAccount: AccountItem,
        completion: @escaping () -> Void
    ) {
        guard controller.presentedViewController == nil else { return }

        let alert: UIAlertController
        if let identity {
            let isPreviouslyUsed = WalletGoogleAccountAssociationStore.shared.association(
                for: recoveryAccount,
                googleUserID: identity.userID
            ) != nil
            alert = UIAlertController(
                title: isPreviouslyUsed
                    ? recoveryText(
                        "wallet.recovery.google.account.previous.title",
                        fallback: "Previous Google Drive account"
                    )
                    : recoveryText(
                        "wallet.recovery.google.account.title",
                        fallback: "Google Drive account"
                    ),
                message: "\(identity.email)\n\n" + recoveryText(
                    "wallet.recovery.google.account.confirm",
                    fallback: "Search this account for the encrypted backup of this wallet?"
                ),
                preferredStyle: .alert
            )
            alert.addAction(
                UIAlertAction(
                    title: recoveryText(
                        "wallet.recovery.google.account.search",
                        fallback: "Search this account"
                    ),
                    style: .default
                ) { [weak controller] _ in
                    guard let controller else { return }
                    runGoogleActionAfterAlert(from: controller) {
                        await continueGoogleRecovery(
                            from: controller,
                            cloudStorage: cloudStorage,
                            confirmedIdentity: identity,
                            recoveryAccount: recoveryAccount,
                            completion: completion
                        )
                    }
                }
            )
        } else {
            alert = UIAlertController(
                title: recoveryText(
                    "wallet.recovery.google.account.unknown.title",
                    fallback: "Google account unknown"
                ),
                message: recoveryText(
                    "wallet.recovery.google.account.unknown.message",
                    fallback: "The older app did not save which Google email was used. Choose an account to check for this wallet's backup."
                ),
                preferredStyle: .alert
            )
        }

        alert.addAction(
            UIAlertAction(
                title: identity == nil
                    ? recoveryText(
                        "wallet.recovery.google.account.choose",
                        fallback: "Choose Google account"
                    )
                    : recoveryText(
                        "wallet.recovery.google.account.another",
                        fallback: "Use another Google account"
                    ),
                style: .default
            ) { [weak controller, weak alert] _ in
                guard let controller, let alert else { return }
                if let identity {
                    guard controller.beginMethodSelection() else { return }
                    presentGoogleAccountSwitchConfirmation(
                        after: alert,
                        from: controller,
                        cloudStorage: cloudStorage,
                        recoveryAccount: recoveryAccount,
                        completion: completion
                    )
                } else {
                    runGoogleActionAfterAlert(from: controller) {
                        await selectGoogleAccount(
                            from: controller,
                            cloudStorage: cloudStorage,
                            recoveryAccount: recoveryAccount,
                            completion: completion
                        )
                    }
                }
            }
        )
        alert.addAction(
            UIAlertAction(
                title: R.string.localizable.commonCancel(preferredLanguages: .currentLocale),
                style: .cancel
            )
        )
        controller.present(alert, animated: true)
    }

    @MainActor
    private static func presentPreviouslyUsedGoogleAccountDecision(
        from controller: RetainedWalletRecoveryViewController,
        cloudStorage: CloudStorageService,
        associations: [WalletGoogleAccountAssociation],
        activeIdentity: CloudStorageAccountIdentity?,
        recoveryAccount: AccountItem,
        completion: @escaping () -> Void
    ) {
        guard controller.presentedViewController == nil else { return }

        var message = associations.map(\.email).joined(separator: "\n") + "\n\n" + recoveryText(
            "wallet.recovery.google.account.previous.help",
            fallback: "Choose this account in Google to check this wallet's backup."
        )
        if let activeIdentity,
           !associations.contains(where: { $0.userID == activeIdentity.userID }) {
            let currentLabel = recoveryText(
                "wallet.recovery.google.account.current",
                fallback: "Currently signed in"
            )
            message += "\n\n\(currentLabel): \(activeIdentity.email)"
        }

        let alert = UIAlertController(
            title: recoveryText(
                "wallet.recovery.google.account.previous.title",
                fallback: "Previous Google Drive account"
            ),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: recoveryText(
                    "wallet.recovery.google.account.choose",
                    fallback: "Choose Google account"
                ),
                style: .default
            ) { [weak controller] _ in
                guard let controller else { return }
                runGoogleActionAfterAlert(from: controller) {
                    await selectGoogleAccount(
                        from: controller,
                        cloudStorage: cloudStorage,
                        recoveryAccount: recoveryAccount,
                        completion: completion
                    )
                }
            }
        )
        alert.addAction(
            UIAlertAction(
                title: R.string.localizable.commonCancel(preferredLanguages: .currentLocale),
                style: .cancel
            )
        )
        controller.present(alert, animated: true)
    }

    @MainActor
    private static func runGoogleActionAfterAlert(
        from controller: RetainedWalletRecoveryViewController,
        action: @escaping @MainActor () async -> Void
    ) {
        guard controller.beginMethodSelection() else { return }
        Task { @MainActor [weak controller] in
            guard let controller else { return }
            let alertDismissed = await waitForPresentedAlertToDismiss(from: controller)
            guard alertDismissed else {
                controller.endMethodSelection()
                return
            }
            await action()
            controller.endMethodSelection()
        }
    }

    @MainActor
    private static func waitForPresentedAlertToDismiss(
        from controller: UIViewController
    ) async -> Bool {
        for _ in 0 ..< 120 {
            if controller.presentedViewController == nil {
                return true
            }
            guard controller.presentedViewController is UIAlertController else {
                return false
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        return false
    }

    @MainActor
    private static func presentGoogleAccountSwitchConfirmation(
        after dismissedAlert: UIAlertController,
        from controller: RetainedWalletRecoveryViewController,
        cloudStorage: CloudStorageService,
        recoveryAccount: AccountItem,
        completion: @escaping () -> Void
    ) {
        Task { @MainActor [weak controller, weak dismissedAlert] in
            guard let controller else { return }
            guard await waitForPresentedAlertToDismiss(from: controller),
                  dismissedAlert?.presentingViewController == nil else {
                controller.endMethodSelection()
                return
            }

            let alert = UIAlertController(
                title: recoveryText(
                    "wallet.recovery.google.switch.title",
                    fallback: "Choose another Google account"
                ),
                message: recoveryText(
                    "wallet.recovery.google.switch.message",
                    fallback: "Google will show its account chooser. Your wallet and Drive backup will not be deleted."
                ),
                preferredStyle: .alert
            )
            alert.addAction(
                UIAlertAction(
                    title: recoveryText(
                        "wallet.recovery.google.switch.continue",
                        fallback: "Choose account"
                    ),
                    style: .default
                ) { [weak controller] _ in
                    guard let controller else { return }
                    Task { @MainActor [weak controller] in
                        guard let controller else { return }
                        guard await waitForPresentedAlertToDismiss(from: controller) else {
                            controller.endMethodSelection()
                            return
                        }
                        await selectGoogleAccount(
                            from: controller,
                            cloudStorage: cloudStorage,
                            recoveryAccount: recoveryAccount,
                            completion: completion
                        )
                        controller.endMethodSelection()
                    }
                }
            )
            alert.addAction(
                UIAlertAction(
                    title: R.string.localizable.commonCancel(
                        preferredLanguages: .currentLocale
                    ),
                    style: .cancel
                ) { [weak controller] _ in
                    controller?.endMethodSelection()
                }
            )
            controller.present(alert, animated: true)
        }
    }

    @MainActor
    private static func selectGoogleAccount(
        from controller: RetainedWalletRecoveryViewController,
        cloudStorage: CloudStorageService,
        recoveryAccount: AccountItem,
        completion: @escaping () -> Void
    ) async {
        do {
            guard let identity = try await cloudStorage.signInSelectingAccount() else {
                controller.setGoogleAccountStatus(.unavailable)
                presentRecoveryUnavailableAlert(from: controller)
                return
            }

            let storedAssociations = WalletGoogleAccountAssociationStore.shared.associations(
                for: recoveryAccount
            )
            if storedAssociations.contains(where: { $0.userID == identity.userID }) {
                controller.setGoogleAccountStatus(
                    .previouslyUsed(emails: storedAssociations.map(\.email))
                )
            } else {
                controller.setGoogleAccountStatus(.available(email: identity.email))
            }
            presentGoogleAccountDecision(
                from: controller,
                cloudStorage: cloudStorage,
                identity: identity,
                recoveryAccount: recoveryAccount,
                completion: completion
            )
        } catch {
            guard !isGoogleSignInCancellation(error) else { return }
            presentRecoveryUnavailableAlert(from: controller)
        }
    }

    @MainActor
    private static func continueGoogleRecovery(
        from controller: RetainedWalletRecoveryViewController,
        cloudStorage: CloudStorageService,
        confirmedIdentity: CloudStorageAccountIdentity,
        recoveryAccount: AccountItem,
        completion: @escaping () -> Void
    ) async {

        do {
            guard try await cloudStorage.signInIfNeeded() == .authorized else {
                presentRecoveryUnavailableAlert(from: controller)
                return
            }
            guard let activeIdentity = cloudStorage.currentAccountIdentity else {
                presentRecoveryUnavailableAlert(from: controller)
                return
            }
            guard activeIdentity.userID == confirmedIdentity.userID else {
                controller.setGoogleAccountStatus(.available(email: activeIdentity.email))
                presentGoogleAccountDecision(
                    from: controller,
                    cloudStorage: cloudStorage,
                    identity: activeIdentity,
                    recoveryAccount: recoveryAccount,
                    completion: completion
                )
                return
            }
            guard let currentAccount = SelectedWalletSettings.shared.currentAccount,
                  sameRecoveryIdentity(currentAccount, recoveryAccount) else {
                presentRecoveryUnavailableAlert(from: controller)
                return
            }
            guard SelectedWalletSettings.transactionSigningAvailability(
                settings: SettingsManager.shared,
                keystore: Keychain(),
                account: currentAccount,
                attemptRepair: false
            ) != .available else {
                controller.dismiss(animated: true, completion: completion)
                return
            }

            let containsExactBackup = try await cloudStorage.containsMobileBackupIfAuthorized(
                address: currentAccount.address,
                expectedAccountUserID: activeIdentity.userID
            )
            guard containsExactBackup else {
                presentNoGoogleBackupAlert(from: controller)
                return
            }

            let exactBackup = OpenBackupAccount(
                name: currentAccount.username,
                address: currentAccount.address
            )
            guard let passwordController = EnterPasswordViewFactory.createView(
                with: exactBackup.address,
                backedUpAccounts: [exactBackup],
                endAddingBlock: completion,
                recoveryAccount: currentAccount,
                googleAccountEmail: activeIdentity.email,
                expectedGoogleAccountID: activeIdentity.userID,
                cloudStorageService: cloudStorage
            )?.controller else {
                presentRecoveryUnavailableAlert(from: controller)
                return
            }

            if let navigationController = controller.navigationController {
                navigationController.pushViewController(passwordController, animated: true)
            } else {
                _ = presentAfterDismissingAlert(from: controller) {
                    controller.present(
                        SoraNavigationController(rootViewController: passwordController),
                        animated: true
                    )
                }
            }
        } catch {
            presentRecoveryUnavailableAlert(from: controller)
        }
    }

    private static func isGoogleSignInCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == kGIDSignInErrorDomain && error.code == -5
    }

    static func sameRecoveryIdentity(_ lhs: AccountItem, _ rhs: AccountItem) -> Bool {
        lhs.address == rhs.address &&
            lhs.publicKeyData == rhs.publicKeyData &&
            lhs.networkType == rhs.networkType &&
            lhs.cryptoType == rhs.cryptoType
    }

    @MainActor
    private static func presentRecoveryUnavailableAlert(from controller: UIViewController) {
        guard controller.presentedViewController == nil else { return }

        let alert = UIAlertController(
            title: R.string.localizable.commonErrorGeneralTitle(
                preferredLanguages: .currentLocale
            ),
            message: R.string.localizable.commonErrorRetry(preferredLanguages: .currentLocale),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                style: .default
            )
        )
        controller.present(alert, animated: true)
    }

    @MainActor
    private static func presentNoGoogleBackupAlert(from controller: UIViewController) {
        guard controller.presentedViewController == nil else { return }

        let alert = UIAlertController(
            title: recoveryText(
                "wallet.recovery.backup.not.found.title",
                fallback: "Backup not found"
            ),
            message: recoveryText(
                "wallet.recovery.backup.not.found",
                fallback: "No Google Drive backup was found for this wallet."
            ),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                style: .default
            )
        )
        controller.present(alert, animated: true)
    }

    @MainActor
    @discardableResult
    static func presentAfterDismissingAlert(
        from controller: UIViewController,
        presentation: @escaping () -> Void
    ) -> Bool {
        guard let presentedController = controller.presentedViewController else {
            presentation()
            return true
        }

        guard presentedController is UIAlertController else {
            return false
        }

        presentedController.dismiss(animated: true, completion: presentation)
        return true
    }

    static func isWalletShellReady(
        hasKeystoreImportService: Bool,
        hasSelectedAccount: Bool,
        hasConnection: Bool,
        hasRuntimeProvider: Bool
    ) -> Bool {
        hasKeystoreImportService &&
            hasSelectedAccount &&
            hasConnection &&
            hasRuntimeProvider
    }

    static func isReadyForCreation() -> Bool {
        let keystoreImportService: KeystoreImportServiceProtocol? =
            URLHandlingService.shared.findService()
        return isWalletShellReady(
            hasKeystoreImportService: keystoreImportService != nil,
            hasSelectedAccount: SelectedWalletSettings.shared.currentAccount != nil,
            hasConnection: ChainRegistryFacade.sharedRegistry.getConnection(
                for: Chain.sora.genesisHash()
            ) != nil,
            hasRuntimeProvider: ChainRegistryFacade.sharedRegistry.getRuntimeProvider(
                for: Chain.sora.genesisHash()
            ) != nil
        )
    }
    
    @MainActor
    static func createView() -> MainTabBarViewProtocol? {
        
        guard let keystoreImportService: KeystoreImportServiceProtocol = URLHandlingService.shared.findService() else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }
        
        let primitiveFactory = WalletPrimitiveFactory(keystore: Keychain())
        
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return nil
        }
        
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        assetManager.setup(for: SelectedWalletSettings.shared)

        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let accountSettings = try? primitiveFactory.createAccountSettings(for: selectedAccount, assetManager: assetManager) else {
            return nil
        }

        let interactor = MainTabBarInteractor(eventCenter: EventCenter.shared,
                                              serviceCoordinator: ServiceCoordinator.shared,
                                              keystoreImportService: keystoreImportService)

        let view = MainTabBarViewController()
        view.localizationManager = LocalizationManager.shared

        let requiresRecoveryReadOnlyMode = SelectedWalletSettings.requiresRecoveryReadOnlyMode(
            settings: SettingsManager.shared,
            keystore: Keychain(),
            account: selectedAccount
        )
        view.recoveryRestoreHandler = { [weak view] in
            _ = presentRetainedWalletRecovery(from: view)
        }
        
        let farmingService = DemeterFarmingService(
            operationFactory: DemeterFarmingOperationFactory(engine: connection),
            fiatService: FiatService.shared,
            assetManager: assetManager
        )
        
        guard let walletContext = try? WalletContextFactory().createContext(connection: connection, 
                                                                            assetManager: assetManager,
                                                                            accountSettings: accountSettings, 
                                                                            demeterFarmingService: farmingService) else {
            return nil
        }
        
        let feeProvider = FeeProvider()
        
        guard let viewControllers = redesignedViewControllers(for: view,
                                                              walletContext: walletContext,
                                                              assetManager: assetManager,
                                                              accountSettings: accountSettings, 
                                                              feeProvider: feeProvider,
                                                              farmingService: farmingService) else {
            return nil
        }
        
        view.viewControllers = viewControllers
        if requiresRecoveryReadOnlyMode {
            view.enableRecoveryReadOnlyMode()
        }
        
        let presenter = MainTabBarPresenter()
        
        let wireframe = MainTabBarWireframe(walletContext: walletContext)
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        
        return view
    }
    
    static func reloadWalletView(on view: MainTabBarViewProtocol,
                                 wireframe: MainTabBarWireframeProtocol) {
        let localizationManager = LocalizationManager.shared
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        assetManager.setup(for: SelectedWalletSettings.shared)
        
        let primitiveFactory = WalletPrimitiveFactory(keystore: Keychain())
        
        guard
            let selectedAccount = SelectedWalletSettings.shared.currentAccount,
            let accountSettings = try? primitiveFactory.createAccountSettings(for: selectedAccount, assetManager: assetManager),
            let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return
        }
        
        let farmingService = DemeterFarmingService(
            operationFactory: DemeterFarmingOperationFactory(engine: connection),
            fiatService: FiatService.shared,
            assetManager: assetManager
        )
        
        guard let walletContext = try? WalletContextFactory().createContext(connection: connection,
                                                                            assetManager: assetManager,
                                                                            accountSettings: accountSettings,
                                                                            demeterFarmingService: farmingService) else {
            return
        }
        
        let assetInfos = assetManager.getAssetList() ?? []
        let providerFactory = BalanceProviderFactory(accountId: accountSettings.accountId,
                                                     cacheFacade: CoreDataCacheFacade.shared,
                                                     networkOperationFactory: walletContext.networkOperationFactory,
                                                     identifierFactory: SingleProviderIdentifierFactory())
        
        let assetsProvider = AssetProvider(assetInfos: assetInfos, providerFactory: providerFactory)
        
        let assetViewModelsFactory = AssetViewModelFactory(walletAssets: assetInfos,
                                            assetManager: assetManager,
                                            fiatService: FiatService.shared)
        
        let assetsViewModelService = AssetsItemService(marketCapService: MarketCapService.shared,
                                                       fiatService: FiatService.shared,
                                                       assetViewModelsFactory: assetViewModelsFactory,
                                                       assetManager: assetManager,
                                                       assetProvider: assetsProvider)
        assetsProvider.add(observer: assetsViewModelService)
        
        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        
        let poolsService = AccountPoolsService(operationManager: OperationManagerFacade.sharedManager,
                                              networkFacade: walletContext.networkOperationFactory,
                                              polkaswapNetworkFacade: polkaswapContext,
                                              config: ApplicationConfig.shared)
        farmingService.poolsService = poolsService
        
        let poolViewModelsfactory = PoolViewModelFactory(walletAssets: assetInfos,
                                            assetManager: assetManager,
                                           fiatService: FiatService.shared)
        
        let poolsViewModelService = PoolsItemService(marketCapService: MarketCapService.shared,
                                           fiatService: FiatService.shared,
                                           poolViewModelsFactory: poolViewModelsfactory)
        poolsService.appendDelegate(delegate: poolsViewModelService)
        
        let editViewService = EditViewService(poolsService: poolsService)
        poolsService.appendDelegate(delegate: editViewService)
        
        let feeProvider = FeeProvider()
        
        guard let sora2Controller = createWalletRedesignController(walletContext: walletContext,
                                                                   assetManager: assetManager,
                                                                   poolsService: poolsService,
                                                                   assetsProvider: assetsProvider,
                                                                   poolsViewModelService: poolsViewModelService,
                                                                   assetsViewModelService: assetsViewModelService,
                                                                   editViewService: editViewService,
                                                                   accountSettings: accountSettings,
                                                                   farmingService: farmingService,
                                                                   feeProvider: feeProvider,
                                                                   localizationManager: localizationManager) else {
            return
        }
        let walletController = wrapPrimaryWalletController(sora2Controller)
        
        wireframe.walletContext = walletContext
        view.didReplaceView(for: walletController, for: Self.walletIndex)
    }
    
    @MainActor
    static func swapDisclamerController(completion: (() -> Void)?) -> UIViewController? {
        let viewModel = SwapDisclaimerViewModel()
        viewModel.completion = completion
        
        let disclamerView = SwapDisclaimerViewController(viewModel: viewModel)
        viewModel.view = disclamerView
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(disclamerView)
        
        return containerView
    }
    
}

//MARK: Redesign

extension MainTabBarViewFactory {
    @MainActor
    private static func redesignedViewControllers(for view: MainTabBarViewController,
                                                  walletContext: CommonWalletContextProtocol,
                                                  assetManager: AssetManagerProtocol,
                                                  accountSettings: WalletAccountSettingsProtocol,
                                                  feeProvider: FeeProviderProtocol,
                                                  farmingService: DemeterFarmingService) -> [UIViewController]? {
        
        let providerFactory = BalanceProviderFactory(accountId: accountSettings.accountId,
                                                     cacheFacade: CoreDataCacheFacade.shared,
                                                     networkOperationFactory: walletContext.networkOperationFactory,
                                                     identifierFactory: SingleProviderIdentifierFactory())
        
        
        let assetInfos = assetManager.getAssetList() ?? []
        let assetsProvider = AssetProvider(assetInfos: assetInfos, providerFactory: providerFactory)
        
        let assetViewModelsFactory = AssetViewModelFactory(walletAssets: assetInfos,
                                            assetManager: assetManager,
                                            fiatService: FiatService.shared)
        
        let assetsViewModelService = AssetsItemService(marketCapService: MarketCapService.shared,
                                                       fiatService: FiatService.shared,
                                                       assetViewModelsFactory: assetViewModelsFactory,
                                                       assetManager: assetManager,
                                                       assetProvider: assetsProvider)
        assetsProvider.add(observer: assetsViewModelService)
        
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return nil
        }
        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        
        let poolsService = AccountPoolsService(operationManager: OperationManagerFacade.sharedManager,
                                              networkFacade: walletContext.networkOperationFactory,
                                              polkaswapNetworkFacade: polkaswapContext,
                                              config: ApplicationConfig.shared)
        farmingService.poolsService = poolsService
        let factory = PoolViewModelFactory(walletAssets: assetInfos,
                                            assetManager: assetManager,
                                           fiatService: FiatService.shared)
        
        let poolsViewModelService = PoolsItemService(marketCapService: MarketCapService.shared,
                                           fiatService: FiatService.shared,
                                           poolViewModelsFactory: factory)

        poolsService.appendDelegate(delegate: poolsViewModelService)
        
        let editViewService = EditViewService(poolsService: poolsService)
        poolsService.appendDelegate(delegate: editViewService)
        
        guard let sora2Controller = createWalletRedesignController(walletContext: walletContext,
                                                                   assetManager: assetManager,
                                                                   poolsService: poolsService,
                                                                   assetsProvider: assetsProvider,
                                                                   poolsViewModelService: poolsViewModelService,
                                                                   assetsViewModelService: assetsViewModelService,
                                                                   editViewService: editViewService,
                                                                   accountSettings: accountSettings,
                                                                   farmingService: farmingService,
                                                                   feeProvider: feeProvider) else {
            return nil
        }
        let walletController = wrapPrimaryWalletController(sora2Controller)
        
        guard let settingsController = createMoreMenuController(walletContext: walletContext,
                                                                assetsProvider: assetsProvider,
                                                                accountSettings: accountSettings) else {
            return nil
        }
        
        guard let activityController = createActivityController(with: assetManager, assetInfos: assetInfos) else {
            return nil
        }
        
        guard let investController = createInvestController(walletContext: walletContext,
                                                            assetManager: assetManager,
                                                            networkFacade: walletContext.networkOperationFactory,
                                                            polkaswapNetworkFacade: polkaswapContext,
                                                            poolsService: poolsService,
                                                            accountSettings: accountSettings,
                                                            assetsProvider: assetsProvider, 
                                                            farmingService: farmingService,
                                                            feeProvider: feeProvider,
                                                            walletAssets: assetInfos) else {
            return nil
        }
        
        let presentSora2Swap: @MainActor () -> Void = { [weak view] in
            guard let view else { return }
            guard let swapViewController = createSwapController(walletContext: walletContext,
                                                                assetManager: assetManager,
                                                                assetsProvider: assetsProvider,
                                                                localizationManager: LocalizationManager.shared) else { return }
            guard let containerView = swapDisclamerController(completion: {
                UserDefaults.standard.set(true, forKey: "isDisclamerShown")
                view.present(swapViewController, animated: true)
            }) else { return }
            
            if ApplicationConfig.shared.isDisclamerShown {
                view.present(swapViewController, animated: true)
            } else {
                view.present(containerView, animated: true)
            }
        }
        view.middleButtonHadler = { [weak view] in
            guard let view else { return }
            let networkSwitch = view.viewControllers?
                .first as? WalletNetworkSwitchViewController
            guard networkSwitch?.selectedNetwork == .sora3 else {
                presentSora2Swap()
                return
            }

            let alert = UIAlertController(
                title: tairaLocalizedText(
                    "wallet_network_polkaswap_sora2_title",
                    fallback: "Polkaswap uses SORA2 Mainnet"
                ),
                message: tairaLocalizedText(
                    "wallet_network_polkaswap_sora2_message",
                    fallback: "Switch to SORA2 Mainnet before opening Polkaswap. Taira Testnet transactions stay separate."
                ),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(
                title: tairaLocalizedText(
                    "wallet_network_switch_to_sora2",
                    fallback: "Switch to SORA2"
                ),
                style: .default,
                handler: { _ in
                    _ = networkSwitch?.select(.sora2, animated: false)
                    presentSora2Swap()
                }
            ))
            alert.addAction(UIAlertAction(
                title: R.string.localizable.commonCancel(
                    preferredLanguages: .currentLocale
                ),
                style: .cancel
            ))
            view.present(alert, animated: true)
        }
        
        let fakeSwapViewController = UIViewController()
        fakeSwapViewController.tabBarItem.isEnabled = false
        
        return  [walletController, investController, fakeSwapViewController, activityController, settingsController]
    }

    static func wrapPrimaryWalletController(
        _ sora2Controller: UIViewController
    ) -> UIViewController {
        // Both callers synchronously mutate the visible tab hierarchy and are
        // required to run on the main thread. Keep that existing synchronous
        // contract while making the actor boundary explicit to Swift.
        MainActor.assumeIsolated {
            guard WalletHomeSora3Target.current != nil else {
                return sora2Controller
            }

            let initialSelection = WalletHomeNetworkSelectionPolicy
                .resolvedSelection(
                    stored: .sora2,
                    sora3Available: true
                )
            let controller = WalletNetworkSwitchViewController(
                sora2Controller: sora2Controller,
                initialSelection: initialSelection,
                makeSora3Controller: {
                    NexusPrimaryWalletViewFactory.createTairaWalletController()
                },
                selectionChanged: { _ in }
            )
            controller.tabBarItem = sora2Controller.tabBarItem
            return controller
        }
    }
    
    static func createWalletRedesignController(walletContext: CommonWalletContextProtocol,
                                               assetManager: AssetManagerProtocol,
                                               poolsService: PoolsServiceInputProtocol,
                                               assetsProvider: AssetProviderProtocol,
                                               poolsViewModelService: PoolsItemService,
                                               assetsViewModelService: AssetsItemService,
                                               editViewService: EditViewServiceProtocol,
                                               accountSettings: WalletAccountSettingsProtocol,
                                               farmingService: DemeterFarmingServiceProtocol,
                                               feeProvider: FeeProviderProtocol,
                                               localizationManager: LocalizationManagerProtocol = LocalizationManager.shared) -> UIViewController? {
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()),
              let runtimeRegistry = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()) else {
            return nil
        }
        
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
            return nil
        }
        
        let qrEncoder = WalletQREncoder(networkType: selectedAccount.networkType,
                                        publicKey: selectedAccount.publicKeyData,
                                        username: selectedAccount.username)
        
        let shareFactory = AccountShareFactory(address: selectedAccount.address,
                                               assets: accountSettings.assets,
                                               localizationManager: localizationManager)
        
        let providerFactory = BalanceProviderFactory(accountId: accountSettings.accountId,
                                                     cacheFacade: CoreDataCacheFacade.shared,
                                                     networkOperationFactory: walletContext.networkOperationFactory,
                                                     identifierFactory: SingleProviderIdentifierFactory())
        
        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        Task {
            await APYService.shared.setup(factory: polkaswapContext)
        }
        
        let referralFactory = ReferralsOperationFactory(settings: SettingsManager.shared,
                                                        keychain: Keychain(),
                                                        engine: connection,
                                                        runtimeRegistry: runtimeRegistry,
                                                        selectedAccount: selectedAccount)
        
        let marketCapService = MarketCapService.shared

        let walletController = RedesignWalletViewFactory.createView(providerFactory: providerFactory,
                                                                    assetManager: assetManager,
                                                                    fiatService: FiatService.shared,
                                                                    farmingService: farmingService,
                                                                    networkFacade: walletContext.networkOperationFactory,
                                                                    accountId: accountSettings.accountId,
                                                                    address: selectedAccount.address,
                                                                    polkaswapNetworkFacade: polkaswapContext,
                                                                    qrEncoder: qrEncoder,
                                                                    sharingFactory: shareFactory,
                                                                    poolsService: poolsService,
                                                                    referralFactory: referralFactory,
                                                                    assetsProvider: assetsProvider,
                                                                    walletContext: walletContext,
                                                                    poolsViewModelService: poolsViewModelService,
                                                                    assetsViewModelService: assetsViewModelService,
                                                                    marketCapService: marketCapService,
                                                                    editViewService: editViewService, 
                                                                    feeProvider: feeProvider)
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.walletTitle(preferredLanguages: locale.rLanguages)
        }
        
        let image = R.image.tabBar.wallet()
        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        
        let navigationController = SoraNavigationController().then {
            $0.navigationBar.isHidden = true
            $0.tabBarItem = createTabBarItem(title: currentTitle, image: image)
            $0.viewControllers = [walletController]
        }
        
        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }
        
        return navigationController
    }
    
    static func createMoreMenuController(
        for localizationManager: LocalizationManagerProtocol = LocalizationManager.shared,
        walletContext: CommonWalletContextProtocol,
        assetsProvider: AssetProviderProtocol,
        accountSettings: WalletAccountSettingsProtocol
    ) -> UIViewController? {
        
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
            return nil
        }
        
        let balanceFactory = BalanceProviderFactory(
            accountId: accountSettings.accountId,
            cacheFacade: CoreDataCacheFacade.shared,
            networkOperationFactory: walletContext.networkOperationFactory,
            identifierFactory: SingleProviderIdentifierFactory()
        )
        
        guard let view = MoreMenuViewFactory.createView(
            walletContext: walletContext,
            fiatService: FiatService.shared,
            balanceFactory: balanceFactory,
            address: selectedAccount.address,
            assetsProvider: assetsProvider,
            assetManager: assetManager
        ) else {
            return nil
        }
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonSettings(preferredLanguages: locale.rLanguages)
        }
        
        let currentTitle = R.string.localizable.commonMore(preferredLanguages: .currentLocale)
        
        let image = R.image.wallet.more()
        
        let navigationController = SoraNavigationController().then {
            $0.navigationBar.topItem?.title = currentTitle
            $0.navigationBar.layoutMargins.left = 16
            $0.navigationBar.layoutMargins.right = 16
            $0.navigationBar.prefersLargeTitles = true
            $0.tabBarItem = createTabBarItem(title: currentTitle, image: image)
            $0.viewControllers = [view.controller]
        }
        
        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }
        
        return navigationController
    }
    
    static func createActivityController(
        with assetManager: AssetManagerProtocol,
        assetInfos: [AssetInfo],
        localizationManager: LocalizationManagerProtocol = LocalizationManager.shared) -> UIViewController? {
            guard let view = ActivityViewFactory.createView(assetManager: assetManager, aseetList: assetInfos) else {
                return nil
            }
            
            let title = R.string.localizable.commonActivity(preferredLanguages: .currentLocale)
            
            let navigationController = SoraNavigationController().then {
                $0.navigationBar.topItem?.title = title
                $0.navigationBar.prefersLargeTitles = true
                $0.navigationBar.layoutMargins.left = 16
                $0.navigationBar.layoutMargins.right = 16
                $0.tabBarItem = createTabBarItem(title: title, image: R.image.wallet.activity())
                $0.viewControllers = [view]
            }
            
            let localizableTitle = LocalizableResource { locale in
                R.string.localizable.commonActivity(preferredLanguages: locale.rLanguages)
            }
            
            localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
                let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
                navigationController?.tabBarItem.title = currentTitle
            }
            
            return navigationController
        }
    
    static func createInvestController(walletContext: CommonWalletContextProtocol,
                                       assetManager: AssetManagerProtocol,
                                       networkFacade: WalletNetworkOperationFactoryProtocol?,
                                       polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
                                       poolsService: PoolsServiceInputProtocol,
                                       accountSettings: WalletAccountSettingsProtocol,
                                       assetsProvider: AssetProviderProtocol,
                                       farmingService: DemeterFarmingServiceProtocol,
                                       feeProvider: FeeProviderProtocol,
                                       walletAssets: [AssetInfo]) -> UINavigationController? {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()),
              let runtimeRegistry = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()) else {
            return nil
        }
        
        let qrEncoder = WalletQREncoder(networkType: selectedAccount.networkType,
                                        publicKey: selectedAccount.publicKeyData,
                                        username: selectedAccount.username)
        
        let marketCapService = MarketCapService.shared
        let fiatService = FiatService.shared
        let itemFactory = ExploreItemFactory(assetManager: assetManager)
        
        let factory = AssetViewModelFactory(walletAssets: walletAssets,
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        let explorePoolsService = ExplorePoolsService(assetInfos: walletAssets,
                                                      fiatService: fiatService,
                                                      polkaswapOperationFactory: polkaswapNetworkFacade,
                                                      networkFacade: networkFacade)
        
        let poolViewModelsService = ExplorePoolsViewModelService(itemFactory: itemFactory,
                                                                poolsService: explorePoolsService,
                                                                apyService: APYService.shared)
        
        let poolFactory = PoolViewModelFactory(walletAssets: walletAssets,
                                               assetManager: assetManager,
                                               fiatService: fiatService)
        
        let providerFactory = BalanceProviderFactory(accountId: accountSettings.accountId,
                                                     cacheFacade: CoreDataCacheFacade.shared,
                                                     networkOperationFactory: walletContext.networkOperationFactory,
                                                     identifierFactory: SingleProviderIdentifierFactory())
        
        let shareFactory = AccountShareFactory(address: selectedAccount.address,
                                               assets: accountSettings.assets,
                                               localizationManager: LocalizationManager.shared)
        
        let referralFactory = ReferralsOperationFactory(settings: SettingsManager.shared,
                                                        keychain: Keychain(),
                                                        engine: connection,
                                                        runtimeRegistry: runtimeRegistry,
                                                        selectedAccount: selectedAccount)
        let accountId = (try? SS58AddressFactory().accountId(
            fromAddress: selectedAccount.address,
            type: selectedAccount.networkType
        ).toHex(includePrefix: true)) ?? ""
        
        let wireframe = ExploreWireframe(fiatService: fiatService,
                                         itemFactory: itemFactory,
                                         assetManager: assetManager,
                                         marketCapService: marketCapService,
                                         explorePoolsService: explorePoolsService,
                                         apyService: APYService.shared,
                                         assetViewModelFactory: factory,
                                         poolsService: poolsService,
                                         poolViewModelsFactory: poolFactory,
                                         providerFactory: providerFactory,
                                         networkFacade: networkFacade,
                                         accountId: accountId,
                                         address: selectedAccount.address,
                                         polkaswapNetworkFacade: polkaswapNetworkFacade,
                                         qrEncoder: qrEncoder,
                                         sharingFactory: shareFactory,
                                         referralFactory: referralFactory,
                                         assetsProvider: assetsProvider,
                                         farmingService: farmingService, 
                                         poolViewModelsService: poolViewModelsService, 
                                         feeProvider: feeProvider, 
                                         walletService: WalletService(operationFactory: walletContext.networkOperationFactory))
        
        let assetViewModelsService = ExploreAssetViewModelService(marketCapService: marketCapService,
                                                                  fiatService: fiatService,
                                                                  itemFactory: itemFactory,
                                                                  assetInfos: walletAssets)
        
        let assetsPageViewModel = ExploreAssetsPageViewModel(wireframe: wireframe,
                                                             assetViewModelsService: assetViewModelsService)
        
        let poolsPageViewModel = ExplorePoolsPageViewModel(wireframe: wireframe,
                                                           poolViewModelsService: poolViewModelsService,
                                                           accountPoolsService: poolsService)
        
        let farmsViewModelsService = ExploreFarmsViewModelService(demeterFarmingService: farmingService)
        
        let farmsPageViewModel = ExploreFarmsPageViewModel(wireframe: wireframe,
                                                           farmsViewModelsService: farmsViewModelsService,
                                                           accountPoolsService: poolsService)
        
        let searchViewModel = ExploreSearchPageViewModel(wireframe: wireframe,
                                                         assetViewModelsService: assetViewModelsService,
                                                         poolViewModelsService: poolViewModelsService,
                                                         farmsViewModelsService: farmsViewModelsService)
        
        let title = R.string.localizable.commonExplore(preferredLanguages: .currentLocale)
        
        let view = ExploreViewController(
            viewModels: [assetsPageViewModel, poolsPageViewModel, farmsPageViewModel],
            searchViewModel: searchViewModel
        )
        view.wireframe = wireframe
        view.localizationManager = LocalizationManager.shared
        
        assetsPageViewModel.view = view
        poolsPageViewModel.view = view
        farmsPageViewModel.view = view
        searchViewModel.view = view
        
        let navigationController = SoraNavigationController().then {
            $0.navigationBar.topItem?.title = title
            $0.navigationBar.layoutMargins.left = 16
            $0.navigationBar.layoutMargins.right = 16
            $0.tabBarItem = createTabBarItem(title: title, image: R.image.wallet.globe())
            $0.viewControllers = [view]
        }
        return navigationController
    }
    
    @MainActor
    static func createSwapController(
        walletContext: CommonWalletContextProtocol,
        assetManager: AssetManagerProtocol,
        assetsProvider: AssetProviderProtocol,
        localizationManager: LocalizationManagerProtocol = LocalizationManager.shared
    ) -> UIViewController? {
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return nil
        }
        
        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        
        let marketCapService = MarketCapService.shared
        
        guard let swapController = SwapViewFactory.createView(selectedTokenId: WalletAssetId.xor.rawValue,
                                                              selectedSecondTokenId: "",
                                                              assetManager: assetManager,
                                                              fiatService: FiatService.shared,
                                                              networkFacade: walletContext.networkOperationFactory,
                                                              polkaswapNetworkFacade: polkaswapContext,
                                                              assetsProvider: assetsProvider,
                                                              marketCapService: marketCapService) else { return nil }
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonAssets(preferredLanguages: locale.rLanguages)
        }
        
        localizationManager.addObserver(with: swapController) { [weak swapController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            swapController?.tabBarItem.title = currentTitle
        }
        
        return swapController
    }
}

private extension MainTabBarViewFactory {
    
    static func createTabBarItem(title: String, image: UIImage?, selectedImage: UIImage? = nil) -> UITabBarItem {
        
        let tabBarItem = UITabBarItem(title: title, image: image, selectedImage: selectedImage)
        
        // Style is set here for compatibility reasons for iOS 12.x and less.
        // For iOS 13 styling see MainTabBarViewController's 'configure' method.
        
        if #available(iOS 13.0, *) {
            return tabBarItem
        }
        
        let normalAttributes = [NSAttributedString.Key.foregroundColor: SoramitsuUI.shared.theme.palette.color(.fgSecondary),
                                NSAttributedString.Key.font: FontType.textBoldXS.font]
        let selectedAttributes = [NSAttributedString.Key.foregroundColor: SoramitsuUI.shared.theme.palette.color(.accentPrimary),
                                  NSAttributedString.Key.font: FontType.textBoldXS.font]
        
        tabBarItem.setTitleTextAttributes(normalAttributes, for: .normal)
        tabBarItem.setTitleTextAttributes(selectedAttributes, for: .selected)
        
        return tabBarItem
    }
}

private extension MainTabBarViewFactory {
    
    static func createNetworkStatusPresenter(localizationManager: LocalizationManagerProtocol = LocalizationManager.shared)
    -> NetworkAvailabilityLayerInteractorOutputProtocol? {
        guard let window = UIApplication.shared.keyWindow as? ApplicationStatusPresentable else {
            return nil
        }
        
        let prenseter = NetworkAvailabilityLayerPresenter()
        prenseter.localizationManager = localizationManager
        prenseter.view = window
        
        return prenseter
    }
}
