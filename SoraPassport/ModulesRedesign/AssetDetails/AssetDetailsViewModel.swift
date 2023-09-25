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
import SCard
import SoraUIKit
import CommonWallet
import RobinHood
import sorawallet

protocol AssetDetailsViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func viewDidLoad()
}

final class AssetDetailsViewModel {
    
    var balanceItems: [SoramitsuTableViewItemProtocol] = []
    var activityItem: RecentActivityItem?
    
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    weak var assetManager: AssetManagerProtocol?
    var assetViewModelFactory: AssetViewModelFactory
    let historyService: HistoryServiceProtocol
    let viewModelFactory: ActivityViewModelFactoryProtocol
    weak var fiatService: FiatServiceProtocol?
    let debouncer = Debouncer(interval: 0.5)
    let eventCenter: EventCenterProtocol
    
    weak var view: AssetDetailsViewProtocol?
    var wireframe: AssetDetailsWireframeProtocol?
    var poolsService: PoolsServiceInputProtocol?
    var assetInfo: AssetInfo
    var poolViewModelsFactory: PoolViewModelFactory
    let providerFactory: BalanceProviderFactory
    let networkFacade: WalletNetworkOperationFactoryProtocol?
    let polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol
    let accountId: String
    let address: String
    let qrEncoder: WalletQREncoderProtocol
    let sharingFactory: AccountShareFactoryProtocol
    private var appEventService = AppEventService()
    private var referralBalance: Decimal?
    private var balanceContext: BalanceContext?
    private var referralFactory: ReferralsOperationFactoryProtocol
    private var fiatData: [FiatData] = []
    private weak var assetsProvider: AssetProviderProtocol?
    private var marketCapService: MarketCapServiceProtocol
    private var priceTrendService: PriceTrendServiceProtocol = PriceTrendService()
    
    init(
        wireframe: AssetDetailsWireframeProtocol?,
        assetInfo: AssetInfo,
        assetViewModelFactory: AssetViewModelFactory,
        assetManager: AssetManagerProtocol?,
        historyService: HistoryServiceProtocol,
        fiatService: FiatServiceProtocol,
        viewModelFactory: ActivityViewModelFactoryProtocol,
        eventCenter: EventCenterProtocol,
        poolsService: PoolsServiceInputProtocol?,
        poolViewModelsFactory: PoolViewModelFactory,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        providerFactory: BalanceProviderFactory,
        accountId: String,
        address: String,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
        qrEncoder: WalletQREncoderProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        referralFactory: ReferralsOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol?,
        marketCapService: MarketCapServiceProtocol
    ) {
        self.accountId = accountId
        self.address = address
        self.assetInfo = assetInfo
        self.assetViewModelFactory = assetViewModelFactory
        self.assetManager = assetManager
        self.fiatService = fiatService
        self.historyService = historyService
        self.viewModelFactory = viewModelFactory
        self.wireframe = wireframe
        self.poolsService = poolsService
        self.poolViewModelsFactory = poolViewModelsFactory
        self.eventCenter = eventCenter
        self.providerFactory = providerFactory
        self.networkFacade = networkFacade
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.qrEncoder = qrEncoder
        self.sharingFactory = sharingFactory
        self.referralFactory = referralFactory
        self.assetsProvider = assetsProvider
        self.marketCapService = marketCapService
        self.eventCenter.add(observer: self)
    }
}

extension AssetDetailsViewModel: AssetDetailsViewModelProtocol {
    func viewDidLoad() {
        let insets = SoramitsuInsets(horizontal: 24, vertical: 8)
        let shimmers = Array(repeating: SoramitsuLoadingTableViewItem(height: 136,
                                                                      type: .shimmer,
                                                                      insets: insets,
                                                                      cornerRadius: .max), count: 4)
        setupItems?(shimmers)
        assetsProvider?.add(observer: self)
    }
}

extension AssetDetailsViewModel: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        updateContent()
    }
}

extension AssetDetailsViewModel: EventVisitorProtocol {
    func processNewTransaction(event: WalletNewTransactionInserted) {
        
        historyService.getHistory(count: 3, assetId: assetInfo.assetId) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let transactions):
                let item = self.updateActivityTtems(with: transactions)

                self.activityItem?.historyViewModels = item.historyViewModels

                if let activityTtem = self.activityItem {
                    self.reloadItems?([ activityTtem ])
                }
                
            case .failure:
                break
            }
        }
    }
}

struct AssetDetailsContent {
    let updateResult: Bool
    let transactions: [Transaction]
    let referralBalance: Decimal?
    let assetPools: [PoolInfo]
}

private extension AssetDetailsViewModel {
    func updateContent() {
        Task {
            async let updateResult = updateContent()
            
            async let transactions = (try? historyService.getHistory(count: 3, assetId: assetInfo.assetId)) ?? []
            
            async let referralBalance = assetInfo.isFeeAsset ? getReferralBalance() : nil
            
            async let pools = poolsService?.loadPools(currentAsset: assetInfo) ?? []

            let assetDetailsContent = await AssetDetailsContent(updateResult: updateResult,
                                                                transactions: transactions,
                                                                referralBalance: referralBalance,
                                                                assetPools: pools)
            setupContent(with: assetDetailsContent)
            
        }
    }
    
    func updateBalanceItems(with balance: BalanceData) async -> [SoramitsuTableViewItemProtocol] {
        return await withCheckedContinuation { continuation in
            Task {
                async let fiatData = self.fiatService?.getFiat() ?? []
                
                async let marketCapInfo = self.marketCapService.getMarketCap()
                
                let poolItemInfo = await PoolItemInfo(fiatData: fiatData, marketCapInfo: marketCapInfo)
                
                let deltaPrice: Decimal? = priceTrendService.getPriceTrend(for: balance.identifier,
                                                                           fiatData: poolItemInfo.fiatData,
                                                                           marketCapInfo: poolItemInfo.marketCapInfo)
                
                guard let assetInfo1 = assetManager?.assetInfo(for: balance.identifier),
                      let viewModel = assetViewModelFactory.createAssetViewModel(with: assetInfo1,
                                                                                 fiatData: poolItemInfo.fiatData,
                                                                                 mode: .view,
                                                                                 priceDelta: deltaPrice) else {
                    continuation.resume(returning: [])
                    return
                }
                
                var fiatBalanceText = ""
                if let usdPrice = poolItemInfo.fiatData.first(where: { $0.id == balance.identifier })?.priceUsd?.decimalValue {
                    let fiatDecimal = balance.balance.decimalValue * usdPrice
                    fiatBalanceText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
                }
                
                let transferableItem = TransferableItem(assetInfo: assetInfo1,
                                                        fiat: fiatBalanceText,
                                                        balance: Amount(value: balance.balance.decimalValue))
                transferableItem.actionHandler = { [weak self] type in
                    guard let self = self, let assetManager = self.assetManager else { return }
                    switch type {
                    case .frozenDetails:
                        self.showFrozenDetails()
                    case .send:
                        guard let networkFacade = self.networkFacade else { return }
                        self.wireframe?.showSend(on: self.view?.controller,
                                                 selectedAsset: self.assetInfo,
                                                 fiatService: self.fiatService,
                                                 assetManager: self.assetManager,
                                                 eventCenter: self.eventCenter,
                                                 providerFactory: self.providerFactory,
                                                 networkFacade: networkFacade,
                                                 assetsProvider: self.assetsProvider,
                                                 qrEncoder: self.qrEncoder,
                                                 sharingFactory: self.sharingFactory,
                                                 marketCapService: self.marketCapService)
                    case .receive:
                        self.wireframe?.showReceive(on: self.view?.controller,
                                                     selectedAsset: self.assetInfo,
                                                     accountId: self.accountId,
                                                     address: self.address,
                                                     qrEncoder: self.qrEncoder,
                                                     sharingFactory: self.sharingFactory,
                                                     fiatService: self.fiatService,
                                                     assetProvider: self.assetsProvider,
                                                     assetManager: self.assetManager)
                    case .swap:
                        guard let fiatService = self.fiatService,
                              let networkFacade = self.networkFacade else { return }
                        self.wireframe?.showSwap(
                            on: self.view?.controller,
                            selectedTokenId: assetInfo1.identifier,
                            assetManager: assetManager,
                            fiatService: fiatService,
                            networkFacade: networkFacade,
                            polkaswapNetworkFacade: self.polkaswapNetworkFacade,
                            assetsProvider: self.assetsProvider,
                            marketCapService: self.marketCapService)
                    case .buy:
                        guard let scard = SCard.shared else { return }
                        self.wireframe?.showXOne(on: self.view?.controller, address: self.address, service: scard)
                    }
                }
                
                let items: [SoramitsuTableViewItemProtocol] = [ PriceItem(assetInfo: assetInfo1, assetViewModel: viewModel),
                                                                SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)),
                                                                transferableItem ]
                continuation.resume(returning: items)
            }
        }
    }
    
    func updateActivityTtems(with transactions: [Transaction]) -> RecentActivityItem {
        let viewModels = transactions.compactMap { viewModelFactory.createActivityViewModel(with: $0) }
        
        let recentActivityItem = RecentActivityItem(historyViewModels: viewModels)
        
        recentActivityItem.openActivityDetailsHandler = { [weak self] blockHash in
            guard let self = self,
                  let transaction = self.historyService.getTransaction(by: blockHash),
                  let assetManager = self.assetManager  else { return }
            
            self.wireframe?.showActivityDetails(on: self.view?.controller, model: transaction, assetManager: assetManager)
        }
        
        recentActivityItem.openFullActivityHandler = { [weak self] in
            guard let self = self, let assetManager = self.assetManager, let controller = self.view?.controller else { return }
            self.wireframe?.showActivity(on: controller, assetId: self.assetInfo.assetId, assetManager: assetManager)
        }
        
        return recentActivityItem
    }
    
    func updatePooledtem(with pools: [PoolInfo]) async -> PooledItem {
        return await withCheckedContinuation { continuation in
            Task {
                async let fiatData = fiatService?.getFiat() ?? []
                
                async let marketCapInfo = marketCapService.getMarketCap()
                
                let poolItemInfo = await PoolItemInfo(fiatData: fiatData, marketCapInfo: marketCapInfo)
                
                let viewModels = pools.compactMap { pool in
                    let priceTrend = priceTrendService.getPriceTrend(for: pool, fiatData: poolItemInfo.fiatData, marketCapInfo: poolItemInfo.marketCapInfo)
                    return self.poolViewModelsFactory.createPoolViewModel(with: pool, fiatData: poolItemInfo.fiatData, mode: .view, priceTrend: priceTrend)
                }
                
                let item = PooledItem(assetInfo: self.assetInfo, poolViewModels: viewModels)
                item.openPoolDetailsHandler = { [weak self] id in
                    guard let self = self,
                          let assetManager = self.assetManager,
                          let fiatService = self.fiatService,
                          let poolsService = self.poolsService,
                          let networkFacade = self.networkFacade,
                          let poolInfo = pools.first(where: { $0.poolId == id }) else { return }
                    self.wireframe?.showPoolDetails(on: self.view?.controller,
                                                     poolInfo: poolInfo,
                                                     assetManager: assetManager,
                                                     fiatService: fiatService,
                                                     poolsService: poolsService,
                                                     providerFactory: self.providerFactory,
                                                     operationFactory: networkFacade,
                                                     assetsProvider: self.assetsProvider,
                                                    marketCapService: self.marketCapService)
                }
                continuation.resume(returning: item)
            }
        }
    }
    
    func getReferralBalance() async -> Decimal? {
        return await withCheckedContinuation { continuation in
            guard let operation = referralFactory.createReferrerBalancesOperation() else { return }
            operation.completionBlock = {
                do {
                    guard let data = try operation.extractResultData()?.underlyingValue else {
                        continuation.resume(with: .success(nil))
                        return
                    }
                    let referralBalance = Decimal.fromSubstrateAmount(data.value, precision: 18) ?? Decimal(0)
                    continuation.resume(with: .success(referralBalance))
                } catch {
                    Logger.shared.error("Request unsuccessful")
                }
            }
            OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .transient)
        }
    }
    
    func updateContent() async -> Bool {
        return await withCheckedContinuation { continuation in
            Task {
                guard let balance = assetsProvider?.getBalances(with: [assetInfo.identifier]).first else { return }
                
                if let context = balance.context {
                    self.balanceContext = BalanceContext(context: context)
                }
                
                let balanceTtems = await self.updateBalanceItems(with: balance)
                
                guard !self.balanceItems.isEmpty else {
                    self.balanceItems = balanceTtems
                    continuation.resume(with: .success(true))
                    return
                }
                
                self.balanceItems.forEach { item in
                    if let item = item as? TransferableItem {
                        item.balance = Amount(value: balance.balance.decimalValue)
                    }
                }
                
                self.reloadItems?(self.balanceItems)
            }
        }
    }
    
    func setupContent(with content: AssetDetailsContent) {
        Task {
            let spacer: SoramitsuTableViewItemProtocol = SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear))
            
            var activityItems: [SoramitsuTableViewItemProtocol] = []
            
            if !content.transactions.isEmpty {
                let activityItem = updateActivityTtems(with: content.transactions)
                activityItems = [ spacer, activityItem ]
                self.activityItem = activityItem
            }
            
            var pooledItems: [SoramitsuTableViewItemProtocol] = []
            
            if !content.assetPools.isEmpty {
                let poolItem = await updatePooledtem(with: content.assetPools)
                pooledItems = [ spacer, poolItem ]
            }
            
            let assetIdItem = AssetIdItem(assetId: assetInfo.assetId, tapHandler: { [weak self] in
                self?.showAppEvent()
            })
            
            balanceItems.compactMap { $0 as? TransferableItem }.first?.isNeedTransferable = !activityItems.isEmpty
            
            let frozen = balanceContext?.frozen ?? Decimal(0)
            let referral = referralBalance ?? Decimal(0)
            let frozenAmount = Amount(value: frozen + referral)
            
            let usdPrice = fiatData.first(where: { $0.id == assetInfo.assetId })?.priceUsd?.decimalValue ?? Decimal(0)
            let frozenFiat = "$" + (NumberFormatter.fiat.stringFromDecimal(frozenAmount.decimalValue * usdPrice) ?? "")
            
            balanceItems.compactMap { $0 as? TransferableItem }.first?.frozenAmount = frozenAmount
            balanceItems.compactMap { $0 as? TransferableItem }.first?.frozenFiatAmount = frozenFiat
            
            setupItems?(balanceItems + pooledItems + activityItems + [ spacer, assetIdItem ])
        }
    }
    
    func showFrozenDetails() {
        let usdPrice = fiatData.first(where: { $0.id == assetInfo.assetId })?.priceUsd?.decimalValue ?? Decimal(0)
        let decimalsDetails: [Decimal] = [
            (balanceContext?.frozen ?? Decimal(0)) + (referralBalance ?? Decimal(0)),
            balanceContext?.locked ?? Decimal(0),
            referralBalance ?? Decimal(0),
            balanceContext?.reserved ?? Decimal(0),
            balanceContext?.redeemable ?? Decimal(0),
            balanceContext?.unbonding ?? Decimal(0)
        ]
        
        let amountDetails = decimalsDetails.compactMap { Amount(value: $0) }
        let fiatDetails = amountDetails.compactMap { NumberFormatter.fiat.stringFromDecimal($0.decimalValue * usdPrice) }
        
        let models = FrozenDetailType.allCases.map { type in
            balanceDetailViewModel(title: type.title,
                                   amount: amountDetails[type.rawValue].stringValue + " " + assetInfo.symbol,
                                   fiatAmount: fiatDetails[type.rawValue],
                                   type: type == .frozen ? .header : .body)
        }
        
        wireframe?.showFrozenBalance(on: view?.controller, frozenDetailViewModels: models)
    }
    
    func showAppEvent() {
        let title = NSAttributedString(string: R.string.localizable.assetDetailsAssetIdCopied(preferredLanguages: .currentLocale))
        let viewModel = AppEventViewController.ViewModel(title: title)
        let appEventController = AppEventViewController(style: .custom(viewModel))
        appEventService.showToasterIfNeeded(viewController: appEventController)
        UIPasteboard.general.string = assetInfo.assetId
    }
    
    func balanceDetailViewModel(title: String, amount: String, fiatAmount: String, type: BalanceDetailType = .body) -> BalanceDetailViewModel {
        let frozenTitleText = SoramitsuTextItem(text: title,
                                                fontData: type.titleFont,
                                                textColor: type.titleColor,
                                                alignment: .left)
        
        let frozenAmountText = SoramitsuTextItem(text: amount,
                                                 fontData: type.amountFont,
                                                 textColor: .fgPrimary,
                                                 alignment: .right)
        
        let frozenFiatText = SoramitsuTextItem(text: "$" + fiatAmount,
                                               fontData: type.fiatAmountFont,
                                               textColor: .fgSecondary,
                                               alignment: .right)
        return BalanceDetailViewModel(title: frozenTitleText, amount: frozenAmountText, fiatAmount: frozenFiatText)
    }
}
