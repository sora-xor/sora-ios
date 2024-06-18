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
import SoraUIKit

import RobinHood
import SCard
import SoraFoundation
import SoraKeystore

enum UpdatedSection {
    case assets
    case pools
}

protocol RedesignWalletViewModelProtocol: AnyObject {
    var reloadItem: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func fetchAssets(completion: @escaping ([SoramitsuTableViewItemProtocol]) -> Void)
    func closeSC()
    func closeSCExchange()
    func closeReferralProgram()
    func updateItems()
    func updateAssets(updatedSection: UpdatedSection)
    func showFullListAssets()
    func showFullListPools()
    func showAssetDetails(with assetInfo: AssetInfo)
    func showPoolDetails(with pool: PoolInfo)
    func showSoraCardDetails()
    func showSoraCardExchange()
    func showInternerConnectionAlert()
    func showReferralProgram(assetManager: AssetManagerProtocol)
    func showEditView(poolsService: PoolsServiceInputProtocol,
                      editViewService: EditViewServiceProtocol,
                      completion: (() -> Void)?)
    func showBackupAccount()
}

final class RedesignWalletViewModel {
    
    var reloadItem: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    var providerFactory: BalanceProviderFactory
    var assetManager: AssetManagerProtocol
    let fiatService: FiatServiceProtocol
    internal let farmingService: DemeterFarmingServiceProtocol
    
    var walletItems: [SoramitsuTableViewItemProtocol] = []
    
    var isReferralProgramHidden: Bool = false
    
    weak var view: RedesignWalletViewProtocol?
    var wireframe: RedesignWalletWireframeProtocol?
    var itemFactory: WalletItemFactoryProtocol
    let networkFacade: WalletNetworkOperationFactoryProtocol
    let polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol
    let poolsService: PoolsServiceInputProtocol
    let accountId: String
    let address: String
    let qrEncoder: WalletQREncoderProtocol
    let sharingFactory: AccountShareFactoryProtocol
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    var referralFactory: ReferralsOperationFactoryProtocol
    var assetsProvider: AssetProviderProtocol
    var walletContext: CommonWalletContextProtocol
    var editViewService: EditViewServiceProtocol
    let feeProvider = FeeProvider()
    let eventCenter = EventCenter.shared
    let marketCapService: MarketCapServiceProtocol
    let poolsViewModelService: PoolsItemService
    let assetsViewModelService: AssetsItemService
    
    init(wireframe: RedesignWalletWireframeProtocol?,
         providerFactory: BalanceProviderFactory,
         assetManager: AssetManagerProtocol,
         fiatService: FiatServiceProtocol,
         farmingService: DemeterFarmingServiceProtocol,
         itemFactory: WalletItemFactoryProtocol,
         networkFacade: WalletNetworkOperationFactoryProtocol,
         accountId: String,
         address: String,
         polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
         qrEncoder: WalletQREncoderProtocol,
         sharingFactory: AccountShareFactoryProtocol,
         poolsService: PoolsServiceInputProtocol,
         referralFactory: ReferralsOperationFactoryProtocol,
         assetsProvider: AssetProviderProtocol,
         walletContext: CommonWalletContextProtocol,
         editViewService: EditViewServiceProtocol,
         poolsViewModelService: PoolsItemService,
         assetsViewModelService: AssetsItemService,
         marketCapService: MarketCapServiceProtocol) {
        self.wireframe = wireframe
        self.accountId = accountId
        self.address = address
        self.providerFactory = providerFactory
        self.assetManager = assetManager
        self.fiatService = fiatService
        self.farmingService = farmingService
        self.itemFactory = itemFactory
        self.networkFacade = networkFacade
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.qrEncoder = qrEncoder
        self.sharingFactory = sharingFactory
        self.referralFactory = referralFactory
        self.assetsProvider = assetsProvider
        self.assetsViewModelService = assetsViewModelService
        self.accountRepository = AnyDataProviderRepository(
            UserDataStorageFacade.shared
            .createRepository(filter: nil,
                              sortDescriptors: [],
                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        )
        self.poolsService = poolsService
        self.walletContext = walletContext
        self.editViewService = editViewService
        self.marketCapService = marketCapService
        self.poolsViewModelService = poolsViewModelService
        self.eventCenter.add(observer: self, dispatchIn: .main)
    }

    internal var xorBalanceStream = SCStream<Decimal>(wrappedValue: Decimal(0))
    internal var balanceProvider: SingleValueProvider<[BalanceData]>?
    internal var totalXorBalance: Decimal?
    internal var singleSidedXorFarmedPools: Decimal?
    internal var referralBalance: Decimal?
}

extension RedesignWalletViewModel: RedesignWalletViewModelProtocol {
    
    func setupModels() {
        let pools = poolsService.getAccountPools()
        loaded(pools: pools)
        
        editViewService.loadModels { [weak editViewService, weak self] isPoolAvailable in
            guard
                let editViewService = editViewService,
                let self = self
            else { return }
            
            var enabledIds = ApplicationConfig.shared.getAvailableApplicationSections()
            let poolId = Cards.pooledAssets.id

            var models = Cards.allCases.map { card in
                EnabledViewModel(id: card.id,
                                 title: card.title,
                                 state: card.defaultState)
            }
            
            if !isPoolAvailable {
                models.removeAll(where: { $0.id == poolId })
                enabledIds.removeAll(where: { $0 == poolId } )
            }
            
            editViewService.viewModels = models
            ApplicationConfig.shared.updateAvailableApplicationSections(cards: enabledIds)
            
            DispatchQueue.main.async {
                if let poolsItem = self.walletItems.first(where: { $0 is PoolsItem }) as? PoolsItem {
                    poolsItem.isHidden = !enabledIds.contains(Cards.pooledAssets.id)
                    self.reloadItem?([poolsItem])
                }
            }
        }
    }

    func closeSC() {
        var config = ApplicationConfig.shared.getAvailableApplicationSections()
        config.removeAll(where: { $0 == Cards.soraCard.id })
        ApplicationConfig.shared.updateAvailableApplicationSections(cards: config)
        SCard.shared?.isSCBannerHidden = true
    }

    func closeSCExchange() {
        var config = ApplicationConfig.shared.getAvailableApplicationSections()
        config.removeAll(where: { $0 == Cards.scExchange.id })
        ApplicationConfig.shared.updateAvailableApplicationSections(cards: config)
    }

    func closeReferralProgram() {
        var config = ApplicationConfig.shared.getAvailableApplicationSections()
        config.removeAll(where: { $0 == Cards.referralProgram.id })
        ApplicationConfig.shared.updateAvailableApplicationSections(cards: config)
        isReferralProgramHidden = true
    }
    
    @MainActor
    func updateItems() {
        var items: [SoramitsuTableViewItemProtocol] = []
        let enabledIds = ApplicationConfig.shared.getAvailableApplicationSections()
        let backupedAccounts = ApplicationConfig.shared.getAvailableBackupedAccounts()
        
        if let accountItem = walletItems.first(where: { $0 is AccountTableViewItem }) {
            items.append(accountItem)
        }
        
        if enabledIds.contains(Cards.soraCard.id) {
            let soraCard = initSoraCard()
            let soraCardItem: SoramitsuTableViewItemProtocol = itemFactory.createSoraCardItem(with: self,
                                                                                              service: soraCard)
            items.append(soraCardItem)
            ConfigService.shared.config.isSoraCardEnabled = true
            soraCard.isSCBannerHidden = false
        }
        
        let isSCUserSignIn = SCard.shared?.isUserSignIn ?? false
        let hasSCIban = SCard.shared?.hasIban ?? false
        if enabledIds.contains(Cards.scExchange.id), isSCUserSignIn, hasSCIban {
            let exchangeItem: SoramitsuTableViewItemProtocol = itemFactory.createSoraCardExchangeItem(with: self)
            items.append(exchangeItem)
        }
        
        if !backupedAccounts.contains(address), let backupItem = walletItems.first(where: { $0 is BackupItem }) {
            items.append(backupItem)
        }
        
        if enabledIds.contains(Cards.referralProgram.id), let friendsItem = walletItems.first(where: { $0 is FriendsItem }) {
            items.append(friendsItem)
        }
        
        if enabledIds.contains(Cards.liquidAssets.id), let assetsItem = walletItems.first(where: { $0 is AssetsItem }) {
            items.append(assetsItem)
        }
        
        if let poolsItem = walletItems.first(where: { $0 is PoolsItem }) as? PoolsItem {
            poolsItem.isHidden = !enabledIds.contains(Cards.pooledAssets.id)
            
            if enabledIds.contains(Cards.pooledAssets.id) {
                items.append(poolsItem)
            }
        }
        
        if let editViewItem = walletItems.first(where: { $0 is EditViewItem }) {
            items.append(editViewItem)
        }
        
        setupItems?(items)
    }

    func updateAssets(updatedSection: UpdatedSection) {
        if updatedSection == .assets {
            (walletItems.filter({ $0 is AssetsItem }).first as? AssetsItem)?.updateContent()
        }
       
        if updatedSection == .pools, walletItems.first(where: { $0 is PoolsItem }) as? PoolsItem != nil {
            let pools = poolsService.getAccountPools() 
            loaded(pools: pools)
        }
    }
    

    @MainActor
    func fetchAssets(completion: @escaping ([SoramitsuTableViewItemProtocol]) -> Void) {
        walletItems = buildItems()
        updateItems()
        setupModels()
    }

    func showSoraCardDetails() {
        let assets = assetManager.getAssetList()?.filter { $0.assetId == WalletAssetId.xor.rawValue } ?? []
        let balanceProvider = try? providerFactory.createBalanceDataProvider(for: assets, onlyVisible: false)
        wireframe?.showSoraCard(on: view?.controller, address: address, balanceProvider: balanceProvider)
    }

    func showSoraCardExchange() {
        wireframe?.showSoraCardExchange(on: view?.controller)
    }

    @MainActor
    private func buildItems() -> [SoramitsuTableViewItemProtocol] {
        
        var items: [SoramitsuTableViewItemProtocol] = []
        
        let accountItem = itemFactory.createAccountItem(with: self,
                                                        view: view,
                                                        wireframe: wireframe,
                                                        feeProvider: feeProvider,
                                                        assetManager: assetManager,
                                                        assetsProvider: assetsProvider,
                                                        fiatService: fiatService,
                                                        networkFacade: networkFacade,
                                                        providerFactory: providerFactory,
                                                        qrEncoder: qrEncoder,
                                                        sharingFactory: sharingFactory,
                                                        accountRepository: accountRepository,
                                                        marketCapService: marketCapService,
                                                        reloadItem: reloadItem)
        
        items.append(accountItem)
        
        let soraCard = initSoraCard()
        let soraCardItem: SoramitsuTableViewItemProtocol = itemFactory.createSoraCardItem(with: self,
                                                                                          service: soraCard)
        items.append(soraCardItem)
        ConfigService.shared.config.isSoraCardEnabled = true
        soraCard.isSCBannerHidden = false

        let exchangeItem: SoramitsuTableViewItemProtocol = itemFactory.createSoraCardExchangeItem(with: self)
        items.append(exchangeItem)

        let backupItem: SoramitsuTableViewItemProtocol = itemFactory.createBackupItem(with: self,
                                                                                      assetManager: assetManager)
        items.append(backupItem)
        
        let friendsItem: SoramitsuTableViewItemProtocol = itemFactory.createInviteFriendsItem(with: self,
                                                                                              assetManager: assetManager)
        items.append(friendsItem)
        isReferralProgramHidden = false
        
        
        let assetItem: SoramitsuTableViewItemProtocol = itemFactory.createAssetsItem(with: self,
                                                                                     assetManager: assetManager,
                                                                                     assetsProvider: assetsProvider,
                                                                                     fiatService: fiatService,
                                                                                     itemService: assetsViewModelService,
                                                                                     marketCapService: marketCapService)
        items.append(assetItem)
        
        
        let poolItem: SoramitsuTableViewItemProtocol = itemFactory.createPoolsItem(with: self,
                                                                                   poolsService: poolsService,
                                                                                   networkFacade: networkFacade,
                                                                                   polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                                                   assetManager: assetManager,
                                                                                   fiatService: fiatService,
                                                                                   poolsViewModelService: poolsViewModelService,
                                                                                   marketCapService: marketCapService)
        items.append(poolItem)
        
        
        let editViewItem: SoramitsuTableViewItemProtocol = itemFactory.createEditViewItem(with: self,
                                                                                          poolsService: poolsService,
                                                                                          editViewService: editViewService)
        items.append(editViewItem)
        
        return items
    }

    @MainActor internal func showReceiveController(in vc: UIViewController) {

        let qrService = WalletQRService(operationFactory: WalletQROperationFactory(), encoder: qrEncoder)

        let viewModel = ReceiveViewModel(
            qrService: qrService,
            sharingFactory: sharingFactory,
            accountId: accountId,
            address: address,
            selectedAsset: .xor,
            fiatService: fiatService,
            assetProvider: assetsProvider,
            assetManager: assetManager
        )

        let receiveController = ReceiveViewController(viewModel: viewModel)
        viewModel.view = receiveController

        let navigationController = UINavigationController(rootViewController: receiveController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()

        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)

        vc.present(containerView, animated: true)
    }

    @MainActor
    internal func showSwapController(in vc: UIViewController) {
        guard let swapController = createSwapController(presenter: vc) else { return }
        vc.present(swapController, animated: true)
    }

    @MainActor
    private func createSwapController(
        presenter: UIViewController,
        localizationManager: LocalizationManagerProtocol = LocalizationManager.shared
    ) -> UIViewController? {
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return nil
        }

        let primitiveFactory = WalletPrimitiveFactory(keystore: Keychain())

        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let accountSettings = try? primitiveFactory.createAccountSettings(for: selectedAccount, assetManager: assetManager) else {
            return nil
        }

        guard let walletContext = try? WalletContextFactory().createContext(
            connection: connection,
            assetManager: assetManager,
            accountSettings: accountSettings, 
            demeterFarmingService: farmingService
        ) else {
            return nil
        }

        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)

        guard let swapController = SwapViewFactory.createView(selectedTokenId: "",
                                                              selectedSecondTokenId: WalletAssetId.xor.rawValue,
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

    func showInternerConnectionAlert() {
        wireframe?.present(message: nil,
                           title: R.string.localizable.connectionErrorMessage(preferredLanguages: .currentLocale),
                           closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                           from: view)
    }

    func showFullListAssets() {
        let assets = assetManager.getAssetList() ?? []
        let factory = AssetViewModelFactory(walletAssets: assets,
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        wireframe?.showFullListAssets(on: view?.controller,
                                      assetManager: assetManager,
                                      fiatService: fiatService,
                                      assetViewModelFactory: factory,
                                      providerFactory: providerFactory,
                                      poolsService: poolsService,
                                      networkFacade: networkFacade,
                                      accountId: accountId,
                                      address: address,
                                      polkaswapNetworkFacade: polkaswapNetworkFacade,
                                      qrEncoder: qrEncoder,
                                      sharingFactory: sharingFactory,
                                      referralFactory: referralFactory,
                                      assetsProvider: assetsProvider,
                                      marketCapService: marketCapService, 
                                      farmingService: farmingService,
                                      updateHandler: updateAssets)
    }
    
    func showFullListPools() {
        let factory = PoolViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                            assetManager: assetManager,
                                           fiatService: fiatService)
        
        wireframe?.showFullListPools(on: view?.controller,
                                     poolsService: poolsService,
                                     networkFacade: networkFacade,
                                     polkaswapNetworkFacade: polkaswapNetworkFacade,
                                     assetManager: assetManager,
                                     fiatService: fiatService,
                                     poolViewModelFactory: factory,
                                     providerFactory: providerFactory,
                                     operationFactory: networkFacade,
                                     assetsProvider: assetsProvider,
                                     marketCapService: marketCapService,
                                     farmingService: farmingService,
                                     updateHandler: updateAssets)
    }
    
    func showAssetDetails(with assetInfo: AssetInfo) {
        let factory = AssetViewModelFactory(walletAssets: [assetInfo],
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        let poolFactory = PoolViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                            assetManager: assetManager,
                                               fiatService: fiatService)
        
        wireframe?.showAssetDetails(on: view?.controller,
                                    assetInfo: assetInfo,
                                    assetManager: assetManager,
                                    fiatService: fiatService,
                                    assetViewModelFactory: factory,
                                    poolsService: poolsService,
                                    poolViewModelsFactory: poolFactory,
                                    providerFactory: providerFactory,
                                    networkFacade: networkFacade,
                                    accountId: accountId,
                                    address: address,
                                    polkaswapNetworkFacade: polkaswapNetworkFacade,
                                    qrEncoder: qrEncoder,
                                    sharingFactory: sharingFactory,
                                    referralFactory: referralFactory,
                                    assetsProvider: assetsProvider,
                                    marketCapService: marketCapService,
                                    farmingService: farmingService)
    }
    
    func showPoolDetails(with pool: PoolInfo) {
        wireframe?.showPoolDetails(on: view?.controller,
                                   poolInfo: pool,
                                   assetManager: assetManager,
                                   fiatService: fiatService,
                                   poolsService: poolsService,
                                   providerFactory: providerFactory,
                                   operationFactory: networkFacade,
                                   assetsProvider: assetsProvider,
                                   marketCapService: marketCapService,
                                   farmingService: farmingService)
    }
    
    func showReferralProgram(assetManager: AssetManagerProtocol) {
        wireframe?.showReferralProgram(from: view,
                                       walletContext: walletContext,
                                       assetManager: assetManager)
    }
    
    func showEditView(poolsService: PoolsServiceInputProtocol,
                      editViewService: EditViewServiceProtocol,
                      completion: (() -> Void)?) {
        wireframe?.showEditView(from: view,
                                poolsService: poolsService,
                                editViewService: editViewService,
                                completion: completion)
    }
    
    func showBackupAccount() {
        wireframe?.showAccountOptions(from: view,
                                      account: SelectedWalletSettings.shared.currentAccount)
    }
}

extension RedesignWalletViewModel: EventVisitorProtocol {
    @MainActor
    func processAccountBackuped(event: AccountBackuped) {
        updateItems()
    }
}
