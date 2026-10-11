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

import SoraFoundation
import SoraUIKit
import SoraKeystore

enum MainTabBarAccountRebindPolicy {
    static let expectedTabCount = 5

    static func requiresRecoveryAfterRebuildFailure(
        boundWalletId: String?,
        selectedWalletId: String?
    ) -> Bool {
        guard selectedWalletId?.isEmpty == false else {
            return true
        }
        return boundWalletId != selectedWalletId
    }

    static func canPresentAccountBoundRoute(
        boundWalletId: String?,
        selectedWalletId: String?,
        routeWalletId: String?,
        recoveryActive: Bool
    ) -> Bool {
        guard
            !recoveryActive,
            let selectedWalletId,
            !selectedWalletId.isEmpty
        else {
            return false
        }
        return boundWalletId == selectedWalletId &&
            routeWalletId == selectedWalletId
    }
}

/// Builds the wallet's tabs again when its first asset list arrives.
///
/// The tabs take the asset list when they are built. Startup does not wait for
/// the on-chain list, so on a launch without a saved list (a first launch, a
/// restore to a new iPhone) the wallet can be open with no asset at all, and
/// would stay empty until the next launch.
///
/// Two rules:
/// - The decision is taken from the list the tabs were built from and the list
///   as it is now, not from an event alone. `WalletAssetListArrived` is posted
///   once, and the tab bar starts listening only when it has appeared; a list
///   that arrived in between is found by the check made at that moment.
/// - Replacing the tabs discards whatever is pushed on a tab or presented over
///   them (a recovery phrase being read, the node list). So the tabs are
///   replaced only while every tab shows its first screen, nothing is
///   presented and no transition is running. Until then the rebuild waits and
///   looks again once a second. (There is no single UIKit callback for "back
///   at a tab's first screen": a pop, an interactive pop, the end of a sheet
///   and a tab switch all lead there.)
///
/// Main thread only, like the wireframe that owns it.
final class WalletAssetListRebuild {
    /// Starts a timer and returns a closure that cancels it.
    typealias Scheduler = (_ delay: TimeInterval, _ fire: @escaping () -> Void) -> () -> Void

    /// How often a waiting rebuild looks again.
    static let recheckInterval: TimeInterval = 1
    /// A rebuild that fails (the tabs could not be built) is tried this often.
    static let maximumFailedRebuilds = 3

    private let schedule: Scheduler
    private(set) var isBuiltWithoutAssets: Bool
    private var cancelRecheck: (() -> Void)?
    private var failedRebuilds = 0

    init(isBuiltWithoutAssets: Bool, schedule: @escaping Scheduler = WalletAssetListRebuild.mainRunLoopTimer) {
        self.isBuiltWithoutAssets = isBuiltWithoutAssets
        self.schedule = schedule
    }

    deinit {
        cancelRecheck?()
    }

    var isWaiting: Bool { cancelRecheck != nil }

    /// The tabs were built, for whatever reason, from `assets`.
    func tabsWereBuilt(from assets: [AssetInfo]) {
        isBuiltWithoutAssets = assets.isEmpty
        failedRebuilds = 0
        cancelRecheck?()
        cancelRecheck = nil
    }

    /// Call whenever the list may have arrived.
    ///
    /// - Parameters:
    ///   - currentAssets: the wallet's asset list as it is now.
    ///   - canReplaceTabs: whether replacing the tabs now would take nothing
    ///     away from the user.
    ///   - rebuild: builds the tabs again; it reports a build that worked
    ///     through `tabsWereBuilt(from:)`.
    func rebuildIfNeeded(
        currentAssets: @escaping () -> [AssetInfo]?,
        canReplaceTabs: @escaping () -> Bool,
        rebuild: @escaping () -> Void
    ) {
        cancelRecheck?()
        cancelRecheck = nil
        guard isBuiltWithoutAssets, currentAssets()?.isEmpty == false else {
            return
        }
        if canReplaceTabs() {
            rebuild()
            guard isBuiltWithoutAssets else {
                return
            }
            failedRebuilds += 1
            guard failedRebuilds < Self.maximumFailedRebuilds else {
                return
            }
        }
        cancelRecheck = schedule(Self.recheckInterval) { [weak self] in
            self?.cancelRecheck = nil
            self?.rebuildIfNeeded(currentAssets: currentAssets, canReplaceTabs: canReplaceTabs, rebuild: rebuild)
        }
    }

    /// Whether the tabs of `tabBarController` can be replaced without taking
    /// a screen away from the user.
    @MainActor
    static func canReplaceTabs(of tabBarController: UITabBarController) -> Bool {
        guard tabBarController.presentedViewController == nil,
              tabBarController.transitionCoordinator == nil else {
            return false
        }
        return (tabBarController.viewControllers ?? []).allSatisfy { controller in
            guard let navigation = controller as? UINavigationController else {
                return true
            }
            return navigation.viewControllers.count <= 1 && navigation.transitionCoordinator == nil
        }
    }

    /// A timer on the main run loop in its default mode: it does not fire
    /// while a scroll or another touch is being tracked.
    static let mainRunLoopTimer: Scheduler = { delay, fire in
        let timer = Timer(timeInterval: max(0, delay), repeats: false) { _ in fire() }
        RunLoop.main.add(timer, forMode: .default)
        return { timer.invalidate() }
    }
}

final class MainTabBarWireframe: MainTabBarWireframeProtocol {
    var walletContext: CommonWalletContextProtocol
    private var walletContextWalletId: String?
    private var accountSwitchRecoveryActive = false
    private var accountBindingId = UUID()
    private let assetListRebuild: WalletAssetListRebuild

    /// - Parameter isBuiltWithoutAssets: the tabs this wireframe belongs to
    ///   were built from an empty asset list.
    init(walletContext: CommonWalletContextProtocol, isBuiltWithoutAssets: Bool = false) {
        self.walletContext = walletContext
        walletContextWalletId =
            SelectedWalletSettings.shared.currentAccount?.address
        assetListRebuild = WalletAssetListRebuild(isBuiltWithoutAssets: isBuiltWithoutAssets)
    }

    private var walletContextMatchesSelectedWallet: Bool {
        guard
            let selectedWalletId =
                SelectedWalletSettings.shared.currentAccount?.address,
            !selectedWalletId.isEmpty
        else {
            return false
        }
        return walletContextWalletId == selectedWalletId
    }

    func showNewWalletView(on view: MainTabBarViewProtocol?) {
        guard
            !accountSwitchRecoveryActive,
            walletContextMatchesSelectedWallet
        else {
            return
        }
        if let view = view {
            MainTabBarViewFactory.reloadWalletView(on: view, wireframe: self)
        }
    }

    func reloadWalletContent() {
        guard
            !accountSwitchRecoveryActive,
            walletContextMatchesSelectedWallet
        else {
            return
        }
        try? walletContext.prepareAccountUpdateCommand().execute()
    }

    func removeClaim(on view: MainTabBarViewProtocol?) {
        guard
            !accountSwitchRecoveryActive,
            walletContextMatchesSelectedWallet
        else {
            return
        }
        guard let tabBarController = view?.controller else {
            return
        }

        tabBarController.dismiss(animated: true) { [weak self] in
            self?.showNewWalletView(on: view)
        }
    }

    @MainActor func presentClaim(on view: MainTabBarViewProtocol?, with service: MigrationServiceProtocol) {
        guard
            !accountSwitchRecoveryActive,
            walletContextMatchesSelectedWallet
        else {
            return
        }
        guard let tabBarController = view?.controller else {
            return
        }

        guard canPresentImport(on: tabBarController) else {
            return
        }

        guard let migrationController = MigrationViewFactory.createViewRedesign(with: service)?.controller else {
            return
        }

        let containerView = BlurViewController()
        containerView.isClosable = false
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(migrationController)
        
        let presentingController = tabBarController.topModalViewController
        presentingController.present(containerView, animated: true, completion: nil)
    }

    func presentAccountImport(on view: MainTabBarViewProtocol?) {
        guard
            !accountSwitchRecoveryActive,
            walletContextMatchesSelectedWallet
        else {
            return
        }
        guard let tabBarController = view?.controller else {
            return
        }

        guard canPresentImport(on: tabBarController) else {
            return
        }

        guard let importController = AccountImportViewFactory
            .createViewForAdding(endAddingBlock: nil)?.controller else {
            return
        }

        let navigationController = SoraNavigationController(rootViewController: importController)

        let presentingController = tabBarController.topModalViewController
        presentingController.present(navigationController, animated: true, completion: nil)
    }

    func showTransactionSuccess(on view: MainTabBarViewProtocol?) {
        guard
            !accountSwitchRecoveryActive,
            walletContextMatchesSelectedWallet
        else {
            return
        }
        if let view = view {
            let title = R.string.localizable.walletTransactionSubmitted(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
            let alert = ModalAlertFactory.createSuccessAlert(title)
            view.controller.present(alert, animated: true, completion: nil)
        }
    }
    
    /// The first asset list may have arrived for tabs that were built
    /// without any asset. See `WalletAssetListRebuild`.
    @MainActor
    func rebuildWalletForArrivedAssetListIfNeeded(on view: MainTabBarViewProtocol?) {
        // The recovery screen of a failed account switch is not replaced by
        // this: it is left by a restart, as it says.
        guard !accountSwitchRecoveryActive, walletContextMatchesSelectedWallet else {
            return
        }
        assetListRebuild.rebuildIfNeeded(
            currentAssets: {
                ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash()).getAssetList()
            },
            canReplaceTabs: { [weak self, weak view] in
                guard let self, !self.accountSwitchRecoveryActive, self.walletContextMatchesSelectedWallet,
                      let tabBarController = view as? UITabBarController else {
                    return false
                }
                return WalletAssetListRebuild.canReplaceTabs(of: tabBarController)
            },
            rebuild: { [weak self, weak view] in
                MainActor.assumeIsolated {
                    self?.recreateWalletViewController(on: view)
                }
            }
        )
    }

    @MainActor
    func recreateWalletViewController(on view: MainTabBarViewProtocol?) {
        guard let tabBarController = view as? UITabBarController else {
            return
        }
        let selectedAccount = SelectedWalletSettings.shared.currentAccount
        let selectedWalletId = selectedAccount?.address
        let requiresRecovery = MainTabBarAccountRebindPolicy
            .requiresRecoveryAfterRebuildFailure(
                boundWalletId: walletContextWalletId,
                selectedWalletId: selectedWalletId
            )

        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        assetManager.setup(for: SelectedWalletSettings.shared)

        let primitiveFactory = WalletPrimitiveFactory(keystore: Keychain())
        
        guard
            let selectedAccount,
            let accountSettings = try? primitiveFactory.createAccountSettings(for: selectedAccount, assetManager: assetManager),
            let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash())
        else {
            handleAccountBoundRebuildFailure(
                requiresRecovery: requiresRecovery,
                tabBarController: tabBarController,
                view: view
            )
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
            handleAccountBoundRebuildFailure(
                requiresRecovery: requiresRecovery,
                tabBarController: tabBarController,
                view: view
            )
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
        
        let factory = PoolViewModelFactory(walletAssets: assetInfos,
                                            assetManager: assetManager,
                                           fiatService: FiatService.shared)
        
        let poolsViewModelService = PoolsItemService(marketCapService: MarketCapService.shared,
                                           fiatService: FiatService.shared,
                                           poolViewModelsFactory: factory)
        poolsService.appendDelegate(delegate: poolsViewModelService)
        
        let editViewService = EditViewService(poolsService: poolsService)
        poolsService.appendDelegate(delegate: editViewService)

        let feeProvider = FeeProvider()

        guard
            let redesignViewController = MainTabBarViewFactory
                .createWalletRedesignController(
                    walletContext: walletContext,
                    assetManager: assetManager,
                    poolsService: poolsService,
                    assetsProvider: assetsProvider,
                    poolsViewModelService: poolsViewModelService,
                    assetsViewModelService: assetsViewModelService,
                    editViewService: editViewService,
                    accountSettings: accountSettings,
                    farmingService: farmingService,
                    feeProvider: feeProvider,
                    localizationManager: LocalizationManager.shared
                ),
            let investController = MainTabBarViewFactory.createInvestController(
                walletContext: walletContext,
                assetManager: assetManager,
                networkFacade: walletContext.networkOperationFactory,
                polkaswapNetworkFacade: polkaswapContext,
                poolsService: poolsService,
                accountSettings: accountSettings,
                assetsProvider: assetsProvider,
                farmingService: farmingService,
                feeProvider: feeProvider,
                walletAssets: assetInfos
            ),
            let activityController = MainTabBarViewFactory
                .createActivityController(
                    with: assetManager,
                    assetInfos: assetInfos
                ),
            let settingsController = MainTabBarViewFactory
                .createMoreMenuController(
                    walletContext: walletContext,
                    assetsProvider: assetsProvider,
                    accountSettings: accountSettings
                )
        else {
            handleAccountBoundRebuildFailure(
                requiresRecovery: requiresRecovery,
                tabBarController: tabBarController,
                view: view
            )
            return
        }

        let replacementBindingId = UUID()
        view?.middleButtonHadler = { [weak self, weak view] in
            guard
                let self,
                self.accountBindingId == replacementBindingId,
                MainTabBarAccountRebindPolicy.canPresentAccountBoundRoute(
                    boundWalletId: self.walletContextWalletId,
                    selectedWalletId: SelectedWalletSettings.shared
                        .currentAccount?.address,
                    routeWalletId: selectedAccount.address,
                    recoveryActive: self.accountSwitchRecoveryActive
                )
            else {
                return
            }
            guard let swapViewController = MainTabBarViewFactory
                .createSwapController(
                    walletContext: walletContext,
                    assetManager: assetManager,
                    assetsProvider: assetsProvider,
                    localizationManager: LocalizationManager.shared
                )
            else {
                return
            }

            guard let containerView = MainTabBarViewFactory
                .swapDisclamerController(
                    completion: { [weak self, weak view] in
                        guard
                            let self,
                            self.accountBindingId == replacementBindingId,
                            MainTabBarAccountRebindPolicy
                                .canPresentAccountBoundRoute(
                                    boundWalletId: self.walletContextWalletId,
                                    selectedWalletId: SelectedWalletSettings
                                        .shared.currentAccount?.address,
                                    routeWalletId: selectedAccount.address,
                                    recoveryActive:
                                        self.accountSwitchRecoveryActive
                                )
                        else {
                            return
                        }
                        UserDefaults.standard.set(
                            true,
                            forKey: "isDisclamerShown"
                        )
                        view?.controller.present(
                            swapViewController,
                            animated: true
                        )
                    }
                )
            else {
                return
            }

            if ApplicationConfig.shared.isDisclamerShown {
                view?.controller.present(swapViewController, animated: true)
            } else {
                view?.controller.present(containerView, animated: true)
            }
        }

        // No title, as in the first build (`MainTabBarViewFactory`): the
        // custom tab bar draws the label of the middle button itself. With a
        // title the system drew "Polkaswap" a second time under it after
        // every rebuild (account switch, language change).
        let fakeSwapViewController = UIViewController()
        fakeSwapViewController.tabBarItem.isEnabled = false

        // Every controller below was built from the same selected account,
        // provider and wallet context. Publish the complete graph once so a
        // factory failure can never leave a retained old-account More tab.
        let replacementViewControllers = [
            redesignViewController,
            investController,
            fakeSwapViewController,
            activityController,
            settingsController,
        ]
        guard replacementViewControllers.count ==
            MainTabBarAccountRebindPolicy.expectedTabCount,
            SelectedWalletSettings.shared.currentAccount?.address ==
                selectedAccount.address
        else {
            handleAccountBoundRebuildFailure(
                requiresRecovery: true,
                tabBarController: tabBarController,
                view: view
            )
            return
        }
        self.walletContext = walletContext
        walletContextWalletId = selectedAccount.address
        accountBindingId = replacementBindingId
        accountSwitchRecoveryActive = false
        assetListRebuild.tabsWereBuilt(from: assetInfos)
        tabBarController.viewControllers = replacementViewControllers
        tabBarController.tabBar.isHidden = false
        
        tabBarController.tabBar.semanticContentAttribute = LocalizationManager.shared.isRightToLeft ? .forceRightToLeft : .forceLeftToRight
    }

    @MainActor
    private func handleAccountBoundRebuildFailure(
        requiresRecovery: Bool,
        tabBarController: UITabBarController,
        view: MainTabBarViewProtocol?
    ) {
        guard requiresRecovery else {
            return
        }

        accountSwitchRecoveryActive = true
        accountBindingId = UUID()
        view?.middleButtonHadler = nil
        let recoveryController = WalletRecoveryViewController(
            reason: [
                "The selected wallet was preserved, but SORA could not rebuild its account-bound screens safely.",
                "Close and reopen SORA to retry. Do not delete or reinstall the app."
            ].joined(separator: " ")
        )
        // The prior tabs retain the old account's providers. Remove the whole
        // graph in one assignment so none can be exposed under the new durable
        // selection while recovery/export assistance remains available.
        tabBarController.viewControllers = [recoveryController]
        tabBarController.selectedIndex = 0
        tabBarController.tabBar.isHidden = true
    }

    // MARK: Private

    private func canPresentImport(on view: UIViewController) -> Bool {
        if isAuthorizing || isAlreadyImporting(on: view) {
            return false
        }

        return true
    }

    private func isAlreadyImporting(on view: UIViewController) -> Bool {
        let topViewController = view.topModalViewController
        let topNavigationController: UINavigationController?

        if let navigationController = topViewController as? UINavigationController {
            topNavigationController = navigationController
        } else if let tabBarController = topViewController as? UITabBarController {
            topNavigationController = tabBarController.selectedViewController as? UINavigationController
        } else {
            topNavigationController = nil
        }

        return topNavigationController?.viewControllers.contains {
            if ($0 as? OnboardingMainViewProtocol) != nil || ($0 as? AccountImportViewProtocol) != nil {
                return true
            } else {
                return false
            }
        } ?? false
    }
}
