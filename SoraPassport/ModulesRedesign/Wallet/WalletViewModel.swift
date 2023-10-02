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
import CommonWallet
import RobinHood
import SCard
import SoraFoundation
import SoraKeystore

protocol RedesignWalletViewModelProtocol: AnyObject {
    var reloadItem: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func fetchAssets(completion: @escaping ([SoramitsuTableViewItemProtocol]) -> Void)
    func closeSC()
    func closeReferralProgram()
    func updateItems()
    func updateAssets()
    func showFullListAssets()
    func showFullListPools()
    func showAssetDetails(with assetInfo: AssetInfo)
    func showPoolDetails(with pool: PoolInfo)
    func showSoraCardDetails()
    func showInternerConnectionAlert()
    func showReferralProgram(assetManager: AssetManagerProtocol)
    func showEditView(poolsService: PoolsServiceInputProtocol,
                      editViewService: EditViewServiceProtocol,
                      completion: (() -> Void)?)
}

final class RedesignWalletViewModel {
    
    var reloadItem: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    var providerFactory: BalanceProviderFactory
    var assetManager: AssetManagerProtocol
    let fiatService: FiatServiceProtocol
    
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
    let marketCapService: MarketCapServiceProtocol
    let poolsViewModelService: PoolsItemService
    let assetsViewModelService: AssetsItemService
    
    init(wireframe: RedesignWalletWireframeProtocol?,
         providerFactory: BalanceProviderFactory,
         assetManager: AssetManagerProtocol,
         fiatService: FiatServiceProtocol,
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
    }

    @SCStream private var xorBalanceStream = SCStream<Decimal>(wrappedValue: Decimal(0))
}

extension RedesignWalletViewModel: RedesignWalletViewModelProtocol {
    
    func setupModels() {
        poolsService.loadAccountPools(isNeedForceUpdate: false)
        editViewService.loadModels { [weak editViewService, weak self] isPoolAvailable in
            guard
                let editViewService = editViewService,
                let self = self
            else { return }
            
            var enabledIds = ApplicationConfig.shared.enabledCardIdentifiers
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
            ApplicationConfig.shared.enabledCardIdentifiers = enabledIds
            ApplicationConfig.shared.accountLoadedPools.insert(self.address)
            
            DispatchQueue.main.async {
                if let poolsItem = self.walletItems.first(where: { $0 is PoolsItem }) as? PoolsItem {
                    poolsItem.isHidden = !enabledIds.contains(Cards.pooledAssets.id)
                    self.reloadItem?([poolsItem])
                }
            }
        }
    }

    func closeSC() {
        ApplicationConfig.shared.enabledCardIdentifiers.removeAll(where: { $0 == Cards.soraCard.id })
        SCard.shared?.isSCBannerHidden = true
    }
    
    func closeReferralProgram() {
        ApplicationConfig.shared.enabledCardIdentifiers.removeAll(where: { $0 == Cards.referralProgram.id })
        isReferralProgramHidden = true
    }
    
    func updateItems() {
        var items: [SoramitsuTableViewItemProtocol] = []
        let enabledIds = ApplicationConfig.shared.enabledCardIdentifiers
        
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

    func updateAssets() {
        if let assetItem = walletItems.first(where: { $0 is AssetsItem }) as? AssetsItem {
            assetItem.updateContent()
        }

        if walletItems.first(where: { $0 is PoolsItem }) as? PoolsItem != nil {
            poolsService.loadAccountPools(isNeedForceUpdate: false)
        }
    }
    

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

    private func initSoraCard() -> SCard {
        guard SCard.shared == nil else { return SCard.shared! }

        let balanceProvider = try? providerFactory.createBalanceDataProvider(for: [.xor], onlyVisible: false)
        let changesBlock = { [weak self] (changes: [DataProviderChange<[BalanceData]>]) -> Void in
            guard let change = changes.first else { return }
            switch change {
            case .insert(let items), .update(let items):
                guard let balane = items.first?.balance.decimalValue else { return }
                self?.xorBalanceStream.wrappedValue = balane
                return
            case .delete(_):
                break
            }
        }

        balanceProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: changesBlock,
            failing: { (error: Error) in },
            options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        )

        var refreshBalanceTimer = Timer()
        refreshBalanceTimer.invalidate()
        refreshBalanceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            balanceProvider?.refresh()
        }

        let soraCard = SCard(
            addressProvider: { SelectedWalletSettings.shared.currentAccount?.address ?? "" },
            config: .test,
            balanceStream: xorBalanceStream,
            onSwapController: { [weak self] vc in
                self?.showSwapController(in: vc)
            }
        )

        SCard.shared = soraCard

        LocalizationManager.shared.addObserver(with: soraCard) { [weak soraCard] (_, newLocalization) in
            soraCard?.selectedLocalization = newLocalization
        }

        return soraCard
    }

    private func showSwapController(in vc: UIViewController) {
        guard let swapController = createSwapController(presenter: vc) else { return }
        vc.present(swapController, animated: true)
    }

    private func createSwapController(
        presenter: UIViewController,
        localizationManager: LocalizationManagerProtocol = LocalizationManager.shared
    ) -> UIViewController? {

        guard
            let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()),
            let walletContext = try? WalletContextFactory().createContext(connection: connection)
        else {
            return nil
        }

        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        assetManager.setup(for: SelectedWalletSettings.shared)


        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return nil
        }

        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        let marketCapService = MarketCapService.shared

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
                                    marketCapService: marketCapService)
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
                                   marketCapService: marketCapService)
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
}
