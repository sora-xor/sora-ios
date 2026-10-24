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
import SoraKeystore

import RobinHood
import SoraFoundation

/// A network row's XOR balance once its read has finished.
enum NetworkRowBalance: Equatable {
    case loaded(String)
    case unavailable
}

enum UpdatedSection {
    case assets
    case pools
}

protocol RedesignWalletViewModelProtocol: AnyObject {
    var reloadItem: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func fetchAssets(completion: @escaping ([SoramitsuTableViewItemProtocol]) -> Void)
    func closeReferralProgram()
    func updateItems()
    func updateAssets(updatedSection: UpdatedSection)
    func showFullListAssets()
    func showFullListPools()
    func showAssetDetails(with assetInfo: AssetInfo)
    func showPoolDetails(with pool: PoolInfo)
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
    /// `portfolioView` (off in Release builds): the portfolio replaces the account header and the
    /// Assets card. Without it the home is exactly what it was.
    let portfolioEnabled: Bool
    var portfolioHome: PortfolioHome?

    /// The selected wallet's accounts on other networks, shown as XOR rows in
    /// the assets list. Never another wallet's: see `refreshNetworkRows()`.
    private var networkAccounts: [NetworkAccount] = []
    private var networkBalances: [String: NetworkRowBalance] = [:]
    private var networkRowsTask: Task<Void, Never>?
    private let nexusReadClient: NexusToriiReading = NexusToriiReadClient()
    
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
         marketCapService: MarketCapServiceProtocol,
         portfolioEnabled: Bool = PortfolioFeature.isEnabled) {
        self.wireframe = wireframe
        self.portfolioEnabled = portfolioEnabled
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
}

extension RedesignWalletViewModel: RedesignWalletViewModelProtocol {
    
    func setupModels() {
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

        if enabledIds.contains(Cards.liquidAssets.id), let assetsItem = walletItems.first(where: { $0 is AssetsItem }) {
            items.append(assetsItem)
        }

        if !backupedAccounts.contains(address), let backupItem = walletItems.first(where: { $0 is BackupItem }) {
            items.append(backupItem)
        }
        
        if let poolsItem = walletItems.first(where: { $0 is PoolsItem }) as? PoolsItem {
            poolsItem.isHidden = !enabledIds.contains(Cards.pooledAssets.id)
            
            if enabledIds.contains(Cards.pooledAssets.id) {
                items.append(poolsItem)
            }
        }
        
        if enabledIds.contains(Cards.referralProgram.id), let friendsItem = walletItems.first(where: { $0 is FriendsItem }) {
            items.append(friendsItem)
        }

        if let editViewItem = walletItems.first(where: { $0 is EditViewItem }) {
            items.append(editViewItem)
        }
        
        if let portfolioHome {
            items = portfolioHome.compose(replacing: items)
        }

        setupItems?(items)
    }

    func updateAssets(updatedSection: UpdatedSection) {
        if updatedSection == .assets {
            (walletItems.filter({ $0 is AssetsItem }).first as? AssetsItem)?.updateContent()
        }
    }
    

    @MainActor
    func fetchAssets(completion: @escaping ([SoramitsuTableViewItemProtocol]) -> Void) {
        walletItems = buildItems()
        updateItems()
        setupModels()
        refreshNetworkRows()
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
        (assetItem as? AssetsItem)?.networkRowHandler = { [weak self] account in
            Task { @MainActor in self?.openNetwork(account: account) }
        }
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

        preparePortfolio(account: accountItem)
        
        return items
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
    
    @MainActor
    func sendFromWallet() {
        startNetworkAction(.send) { [weak self] in
            self?.showSora2Send()
        }
    }

    @MainActor
    func receive(showSora2Receive: @escaping () -> Void) {
        startNetworkAction(.receive, sora2: showSora2Receive)
    }

    @MainActor
    private func showSora2Send() {
        wireframe?.showSend(on: view?.controller, selectedTokenId: nil, selectedAddress: "",
                            fiatService: fiatService, assetManager: assetManager,
                            providerFactory: providerFactory, networkFacade: networkFacade,
                            assetsProvider: assetsProvider, qrEncoder: qrEncoder,
                            sharingFactory: sharingFactory, marketCapService: marketCapService)
    }

    /// Send and Receive ask which network only when there is a real choice;
    /// otherwise they open SORA2's flow exactly as before.
    @MainActor
    private func startNetworkAction(_ action: WalletNetworkAction, sora2: @escaping () -> Void) {
        let accounts = WalletNetworkAccounts.selectedWallet()
        guard
            accounts.contains(where: { $0.networkId == .sora2 }),
            accounts.contains(where: { $0.networkId != .sora2 }),
            let source = view?.controller
        else {
            sora2()
            return
        }
        let sendable = Set(accounts.map(\.networkId).filter { WalletNetworkAccounts.canSend(on: $0) })
        let choices = WalletNetworkChoices.make(
            action: action,
            accounts: accounts,
            balances: networkBalanceTexts(for: accounts),
            canSend: { sendable.contains($0) }
        )
        let open: @MainActor (WalletNetworkChoice) -> Void = { [weak self] choice in
            if choice.account.networkId == .sora2 {
                sora2()
            } else {
                self?.openNetwork(account: choice.account, startSend: action == .send)
            }
        }
        if let only = WalletNetworkChoices.onlyChoice(choices) {
            open(only)
            return
        }
        WalletNetworkPickerViewController.present(action: action, choices: choices, from: source, onPick: open)
    }

    /// XOR on a network other than SORA2: its balance, receive address,
    /// history and, where the network allows it, Send.
    @MainActor
    func openNetwork(account: NetworkAccount, startSend: Bool = false) {
        let settings = SettingsManager.shared
        guard
            ProductSurfacePolicy.showsNexusPortfolio,
            settings.nexusEnabled,
            account.walletId == SelectedWalletSettings.shared.currentAccount?.address,
            NexusPortfolioPresentationPolicy.networkDetailIsAvailable(
                networkId: account.networkId,
                nexusEnabled: settings.nexusEnabled,
                tairaEnabled: settings.isTairaEnabled,
                tairaAdmitted: NexusNetworkAdmissionPolicy.current.isTairaAdmitted
            ),
            let configuration = NexusNetworkConfiguration.configuration(for: account.networkId),
            let navigation = view?.controller.navigationController
        else {
            return
        }
        let runtime = NexusTransactionRuntime.shared
        let detail = NexusNetworkDetailViewController(
            account: account,
            configuration: configuration,
            coordinator: runtime.coordinator,
            readClient: nexusReadClient,
            mutationUnavailableReason: runtime.initializationFailed
                ? NexusPortfolioPresentationPolicy.journalUnavailableMessage
                : nil,
            opensSendWhenReady: startSend
        )
        navigation.setNavigationBarHidden(false, animated: false)
        detail.hidesBottomBarWhenPushed = true
        navigation.pushViewController(detail, animated: true)
    }

    /// Reloads the other networks' XOR rows for the selected wallet. Account
    /// selection is a privacy boundary: rows and balances of any other wallet
    /// are dropped before anything is read.
    @MainActor
    func refreshNetworkRows() {
        networkRowsTask?.cancel()
        let accounts = WalletNetworkAccounts.selectedWallet()
        networkBalances = networkBalances.filter { key, _ in accounts.contains { $0.id == key } }
        networkAccounts = accounts
        applyNetworkRows()
        let liveAccounts = accounts.filter {
            $0.networkId != .sora2 && WalletNetworkDirectory.current.info($0.networkId).isLive
        }
        guard !liveAccounts.isEmpty else {
            return
        }
        let readClient = nexusReadClient
        networkRowsTask = Task { [weak self] in
            for account in liveAccounts {
                guard let configuration = NexusNetworkConfiguration.configuration(for: account.networkId) else {
                    continue
                }
                let balance: NetworkRowBalance
                do {
                    let current = try await readCurrentNexusXorBalance(
                        account: account,
                        configuration: configuration,
                        readClient: readClient
                    )
                    balance = .loaded(current.quantity.rawValue)
                } catch {
                    if NexusPortfolioTaskPolicy.isCancellation(error) {
                        return
                    }
                    balance = .unavailable
                }
                guard
                    let self,
                    !Task.isCancelled,
                    account.walletId == SelectedWalletSettings.shared.currentAccount?.address,
                    self.networkAccounts.contains(account)
                else {
                    return
                }
                self.networkBalances[account.id] = balance
                self.applyNetworkRows()
            }
        }
    }

    @MainActor
    private func applyNetworkRows() {
        guard let assetsItem = walletItems.first(where: { $0 is AssetsItem }) as? AssetsItem else {
            return
        }
        let directory = WalletNetworkDirectory.current
        let main = directory.mainNetwork(walletNetworks: Set(networkAccounts.map(\.networkId)))
        let xor = assetManager.assetInfo(for: WalletAssetId.xor.rawValue)
        let icon = xor.flatMap { RemoteSerializer.shared.image(with: $0.icon ?? "") }
        let name = xor?.name ?? "XOR"
        let rows: [NetworkAssetRow] = directory.ordered(networkAccounts.map(\.networkId), main: main)
            .filter { $0 != .sora2 }
            .compactMap { networkId in
                guard let account = networkAccounts.first(where: { $0.networkId == networkId }) else {
                    return nil
                }
                let network = directory.info(networkId)
                let amount: String
                if !network.isLive {
                    amount = WalletUX.text("Address ready")
                } else {
                    switch networkBalances[account.id] {
                    case let .loaded(quantity):
                        amount = "\(Self.xorText(quantity)) XOR"
                    case .unavailable:
                        amount = WalletUX.balanceUnavailableText
                    case nil:
                        amount = ""
                    }
                }
                return NetworkAssetRow(
                    account: account,
                    title: directory.rowLabel(for: networkId, main: main).map { "\(name) · \($0)" } ?? name,
                    amount: amount,
                    tag: directory.tag(for: networkId, main: main),
                    icon: icon,
                    isMain: networkId == main
                )
            }
        let sora2Label = directory.rowLabel(for: .sora2, main: main)
        guard assetsItem.networkRows != rows || assetsItem.sora2RowLabel != sora2Label else {
            return
        }
        assetsItem.networkRows = rows
        assetsItem.sora2RowLabel = sora2Label
        reloadItem?([assetsItem])
    }

    /// XOR balances by network for the Receive and Send choices.
    @MainActor
    private func networkBalanceTexts(for accounts: [NetworkAccount]) -> [NetworkId: String] {
        var texts: [NetworkId: String] = [:]
        if let sora2 = assetsProvider.getBalances(with: [WalletAssetId.xor.rawValue]).first {
            texts[.sora2] = Self.xorText(sora2.balance.stringValue)
        }
        for account in accounts {
            if case let .loaded(quantity) = networkBalances[account.id] {
                texts[account.networkId] = Self.xorText(quantity)
            }
        }
        return texts
    }

    private static func xorText(_ quantity: String) -> String {
        guard let value = Decimal(string: quantity, locale: Locale(identifier: "en_US_POSIX")) else {
            return quantity
        }
        return NumberFormatter.cryptoAmounts.stringFromDecimal(value) ?? quantity
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

    /// Switching account in a sheet does not make the wallet reappear; drop
    /// the previous wallet's network rows at once.
    @MainActor
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        refreshNetworkRows()
    }
}
