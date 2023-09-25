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
import SoraFoundation
import XNetworking

final class RemoveLiquidityViewModel {
    var detailsItem: PoolDetailsItem?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var completionHandler: (() -> Void)?
    
    weak var fiatService: FiatServiceProtocol?
    weak var apyService: APYServiceProtocol?
    weak var view: LiquidityViewProtocol?
    var wireframe: LiquidityWireframeProtocol?
    var poolsService: PoolsServiceInputProtocol?
    let assetManager: AssetManagerProtocol?
    let detailsFactory: DetailViewModelFactoryProtocol
    let operationFactory: WalletNetworkOperationFactoryProtocol
    
    let debouncer = Debouncer(interval: 0.8)
    
    var providerFactory: BalanceProviderFactory

    var title: String? {
        return R.string.localizable.removeLiquidityTitle(preferredLanguages: .currentLocale)
    }
    
    var imageName: String? {
        return nil
    }
    
    var isSwap: Bool {
        return false
    }
    
    var actionButtonImage: UIImage? {
        return R.image.wallet.plus()
    }
    
    var middleButtonActionHandler: (() -> Void)?
    
    var poolInfo: PoolInfo? {
        didSet {
            updatePairInfo()
            updateDetails()
            updateButtonState()
        }
    }
    
    var details: [DetailViewModel] = [] {
        didSet {
            DispatchQueue.main.async {
                self.view?.update(details: self.details)
            }
        }
    }
    
    var firstAssetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            setupFullBalanceText(from: firstAssetBalance) { [weak self] text in
                DispatchQueue.main.async {
                    self?.view?.updateFirstAsset(balance: text)
                }
            }
        }
    }
    
    var secondAssetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            setupFullBalanceText(from: secondAssetBalance) { [weak self] text in
                DispatchQueue.main.async {
                    self?.view?.updateSecondAsset(balance: text)
                }
            }
        }
    }
    
    var firstAssetId: String = "" {
        didSet {
            Task {
                guard let asset = assetManager?.assetInfo(for: firstAssetId) else { return }
                let image = RemoteSerializer.shared.image(with: asset.icon ?? "")
                view?.updateFirstAsset(symbol: asset.symbol, image: image)
                setupBalanceDataProvider()
                if !firstAssetId.isEmpty, !secondAssetId.isEmpty {
                    poolInfo = await poolsService?.getPool(by: firstAssetId, targetAssetId: secondAssetId)
                }
                recalculate(field: .one)
            }
        }
    }
    
    var secondAssetId: String = "" {
        didSet {
            Task {
                guard let asset = assetManager?.assetInfo(for: secondAssetId) else { return }
                let image = RemoteSerializer.shared.image(with: asset.icon ?? "")
                view?.updateSecondAsset(symbol: asset.symbol, image: image)
                setupBalanceDataProvider()
                if !firstAssetId.isEmpty, !secondAssetId.isEmpty {
                    poolInfo = await poolsService?.getPool(by: firstAssetId, targetAssetId: secondAssetId)
                }
                recalculate(field: .two)
            }
        }
    }
    
    var inputedFirstAmount: Decimal = 0 {
        didSet {
            guard poolInfo != nil else { return }

            let formatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            
            if availableBaseAssetPooledByAccount <= inputedFirstAmount {
                inputedFirstAmount = availableBaseAssetPooledByAccount
                view?.set(firstAmountText: formatter.stringFromDecimal(inputedFirstAmount) ?? "")
            }

            setupInputedFiatText(from: inputedFirstAmount, assetId: firstAssetId) { [weak self] text in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let state: InputFieldState = self.focusedField == .one ? .focused : .default
                    self.view?.updateFirstAsset(state: state, amountColor: .fgPrimary, fiatColor: .fgSecondary)
                    self.view?.updateFirstAsset(fiatText: text)
                }
            }
        }
    }
    
    var inputedSecondAmount: Decimal = 0 {
        didSet {
            guard poolInfo != nil else { return }

            let formatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: secondAssetId)?.precision ?? 0)
            
            if availableTargetAssetPooledByAccount <= inputedSecondAmount {
                inputedSecondAmount = availableTargetAssetPooledByAccount
                view?.set(secondAmountText: formatter.stringFromDecimal(inputedSecondAmount) ?? "")
            }

            setupInputedFiatText(from: inputedSecondAmount, assetId: secondAssetId) { [weak self] text in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let state: InputFieldState = self.focusedField == .two ? .focused : .default
                    self.view?.updateSecondAsset(state: state, amountColor: .fgPrimary, fiatColor: .fgSecondary)
                    self.view?.updateSecondAsset(fiatText: text)
                }
            }
        }
    }
    
    var slippageTolerance: Float = 0.5 {
        didSet {
            let slippageToleranceText = "\(slippageTolerance)%"
            view?.update(slippageTolerance: slippageToleranceText)
        }
    }
    
    var focusedField: FocusedField = .one
    
    private var warningViewModel: WarningViewModel? {
        didSet {
            guard let warningViewModel else { return }
            view?.updateWarinignView(model: warningViewModel)
        }
    }
    
    private let feeProvider: FeeProviderProtocol
    private var fiatData: [FiatData] = [] {
        didSet {
            setupBalanceDataProvider()
        }
    }
    private var apy: Decimal?
    private var fee: Decimal = 0
    
    private var isPairEnabled: Bool = true
    private var isPairPresented: Bool = true
    
    private weak var assetsProvider: AssetProviderProtocol?
    private let farmingService: DemeterFarmingServiceProtocol
    private var stakedPools: [StakedPool] = []
    private var warningViewModelFactory: WarningViewModelFactory
    private var marketCapService: MarketCapServiceProtocol
    private var stackedPercentage: Decimal {
        return stakedPools.map {
            let accountPoolBalance = poolInfo?.accountPoolBalance ?? .zero
            let pooledTokens = Decimal.fromSubstrateAmount($0.pooledTokens, precision: 18) ?? .zero
            return accountPoolBalance > 0 ? (pooledTokens / accountPoolBalance) : 0
        }.max() ?? Decimal.zero
    }
    
    private var availableBaseAssetPooledByAccount: Decimal {
        guard let poolInfo = poolInfo, let baseAssetPooledByAccount = poolInfo.baseAssetPooledByAccount else { return .zero }
        return baseAssetPooledByAccount - baseAssetPooledByAccount * stackedPercentage
    }
    
    private var availableTargetAssetPooledByAccount: Decimal {
        guard let poolInfo = poolInfo, let targetAssetPooledByAccount = poolInfo.targetAssetPooledByAccount else { return .zero }
        return targetAssetPooledByAccount - targetAssetPooledByAccount * stackedPercentage
    }
    
    init(
        wireframe: LiquidityWireframeProtocol?,
        poolInfo: PoolInfo,
        stakedPools: [StakedPool],
        apyService: APYServiceProtocol?,
        fiatService: FiatServiceProtocol?,
        poolsService: PoolsServiceInputProtocol?,
        assetManager: AssetManagerProtocol?,
        detailsFactory: DetailViewModelFactoryProtocol,
        providerFactory: BalanceProviderFactory,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol?,
        farmingService: DemeterFarmingServiceProtocol,
        warningViewModelFactory: WarningViewModelFactory = WarningViewModelFactory(),
        marketCapService: MarketCapServiceProtocol
    ) {
        self.poolInfo = poolInfo
        self.apyService = apyService
        self.fiatService = fiatService
        self.wireframe = wireframe
        self.poolsService = poolsService
        self.assetManager = assetManager
        self.detailsFactory = detailsFactory
        self.providerFactory = providerFactory
        self.feeProvider = FeeProvider()
        self.operationFactory = operationFactory
        self.assetsProvider = assetsProvider
        self.farmingService = farmingService
        self.stakedPools = stakedPools
        self.warningViewModelFactory = warningViewModelFactory
        self.marketCapService = marketCapService
    }
}

extension RemoveLiquidityViewModel: LiquidityViewModelProtocol {
    func didSelect(variant: Float) {
        if focusedField == .one {
            guard poolInfo != nil else { return }
            let value = availableBaseAssetPooledByAccount * (Decimal(string: "\(variant)") ?? 0)
            let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            view?.set(firstAmountText: formatter.stringFromDecimal(value) ?? "")
            inputedFirstAmount = value
        }
        
        if focusedField == .two {
            guard poolInfo != nil else { return }
            let value = availableTargetAssetPooledByAccount * (Decimal(string: "\(variant)") ?? 0)
            let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: secondAssetId)?.precision ?? 0)
            view?.set(secondAmountText: formatter.stringFromDecimal(value) ?? "")
            inputedSecondAmount = value
        }
        
        recalculate(field: focusedField)
    }

    func viewDidLoad() {
        if let firstAssetId = poolInfo?.baseAssetId {
            self.firstAssetId = firstAssetId
        }
        
        if let secondAssetId = poolInfo?.targetAssetId {
            self.secondAssetId = secondAssetId
        }

        slippageTolerance = 0.5
        assetsProvider?.add(observer: self)
        view?.focus(field: .one)
    }
    
    func infoButtonTapped() {
        wireframe?.present(
            message: R.string.localizable.removeLiquidityInfoText(),
            title: R.string.localizable.removeLiquidityTitle(),
            closeAction: R.string.localizable.commonOk(),
            from: view
        )
    }
    
    func apyInfoButtonTapped() {
        wireframe?.present(
            message: R.string.localizable.polkaswapSbApyInfo(),
            title: Constants.apyTitle,
            closeAction: R.string.localizable.commonOk(),
            from: view
        )
    }
    
    func choiсeBaseAssetButtonTapped() {
        guard let assetManager = assetManager,
              let fiatService = fiatService,
              let xorAsset = assetManager.assetInfo(for: WalletAssetId.xor.rawValue),
              let xstUsdAsset = assetManager.assetInfo(for: WalletAssetId.xstusd.rawValue) else { return }

        let assets = [xorAsset, xstUsdAsset].filter({ $0.identifier != secondAssetId })
        
        let factory = AssetViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        wireframe?.showChoiсeBaseAsset(on: view?.controller,
                                       assetManager: assetManager,
                                       fiatService: fiatService,
                                       assetViewModelFactory: factory,
                                       assetsProvider: assetsProvider,
                                       assetIds: assets.map { $0.identifier },
                                       marketCapService: marketCapService) { [weak self] assetId in
            self?.firstAssetId = assetId
        }
    }
    
    func choiсeTargetAssetButtonTapped() {
        let targetAssetIds: [String] = poolsService?.loadTargetPools(for: firstAssetId).map { $0.targetAssetId } ?? []
        
        guard let assetManager = assetManager,
              let fiatService = fiatService,
              let assets = assetManager.getAssetList()?.filter({ targetAssetIds.contains($0.identifier) }) else { return }
        
        let factory = AssetViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        wireframe?.showChoiсeBaseAsset(on: view?.controller,
                                       assetManager: assetManager,
                                       fiatService: fiatService,
                                       assetViewModelFactory: factory,
                                       assetsProvider: assetsProvider,
                                       assetIds: assets.map { $0.identifier },
                                       marketCapService: marketCapService) { [weak self] assetId in
            self?.secondAssetId = assetId
        }
    }
    
    func changeSlippageTolerance() {
        wireframe?.showSlippageTolerance(on: view?.controller.navigationController,
                                         currentLocale: slippageTolerance,
                                         completion: { [weak self] slippageTolerance in
            self?.slippageTolerance = slippageTolerance
        })
    }
    
    func reviewButtonTapped() {
        guard let poolInfo = poolInfo, let assetManager = assetManager else { return }
        wireframe?.showRemoveLiquidityConfirmation(on: view?.controller.navigationController,
                                                   poolInfo: poolInfo,
                                                   assetManager: assetManager,
                                                   firstAssetAmount: inputedFirstAmount,
                                                   secondAssetAmount: inputedSecondAmount,
                                                   slippageTolerance: slippageTolerance,
                                                   details: details,
                                                   fee: fee,
                                                   operationFactory: operationFactory,
                                                   completionHandler: completionHandler)
    }
    
    func recalculate(field: FocusedField) {
        guard let poolInfo = poolInfo else { return }

        if focusedField == .one {
            let formatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            let scale = (poolInfo.targetAssetPooledTotal ?? 0) / (poolInfo.baseAssetPooledTotal ?? 0)
            inputedSecondAmount = inputedFirstAmount * scale
            view?.set(secondAmountText: formatter.stringFromDecimal(inputedSecondAmount) ?? "")
            updateButtonState()
            debouncer.perform { [weak self] in
                self?.updateDetails()
            }
        } else {
            let formatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: secondAssetId)?.precision ?? 0)
            let scale = (poolInfo.baseAssetPooledTotal ?? 0) / (poolInfo.targetAssetPooledTotal ?? 0)
            inputedFirstAmount = inputedSecondAmount * scale
            view?.set(firstAmountText: formatter.stringFromDecimal(inputedFirstAmount) ?? "")
            updateButtonState()
            debouncer.perform { [weak self] in
                self?.updateDetails()
            }
        }
    }
}

extension RemoveLiquidityViewModel: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        setupBalanceDataProvider()
    }
}

extension RemoveLiquidityViewModel {
    
    func setupBalanceDataProvider() {
        if !firstAssetId.isEmpty, let firstAssetBalance = assetsProvider?.getBalances(with: [firstAssetId]).first {
            self.firstAssetBalance = firstAssetBalance
        }
        
        if !secondAssetId.isEmpty, let secondAssetBalance = assetsProvider?.getBalances(with: [secondAssetId]).first {
            self.secondAssetBalance = secondAssetBalance
        }
    }
    
    func setupFullBalanceText(from balanceData: BalanceData, complention: @escaping (String) -> Void) {
        let balance = NumberFormatter.polkaswapBalance.stringFromDecimal(balanceData.balance.decimalValue) ?? ""
        var fiatBalanceText = ""
        
        if let usdPrice = fiatData.first(where: { $0.id == balanceData.identifier })?.priceUsd?.decimalValue {
            let fiatDecimal = balanceData.balance.decimalValue * usdPrice
            fiatBalanceText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        let balanceText = fiatBalanceText.isEmpty ? "\(balance)" : "\(balance) (\(fiatBalanceText))"
        complention(balanceText)
    }
    
    func setupInputedFiatText(from inputedAmount: Decimal, assetId: String, complention: @escaping (String) -> Void) {
        guard let asset = assetManager?.assetInfo(for: assetId) else { return }
        
        var fiatText = ""
        
        if let usdPrice = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = inputedAmount * usdPrice
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        complention(fiatText)
    }
    
    func updatePairInfo() {
        guard !firstAssetId.isEmpty, !secondAssetId.isEmpty else {
            return
        }

        poolsService?.isPairPresentedInNetwork(baseAssetId: firstAssetId,
                                               targetAssetId: secondAssetId,
                                               accountId: "",
                                               completion: { [weak self] isPresented in
            self?.isPairPresented = isPresented
        })
        
        poolsService?.isPairEnabled(baseAssetId: firstAssetId,
                                    targetAssetId: secondAssetId,
                                    accountId: "",
                                    completion: { [weak self] isEnabled in
            self?.isPairEnabled = isEnabled
        })
    }
    
    func updateDetails() {
        let group = DispatchGroup()
        
        group.enter()
        fiatService?.getFiat { [weak self] fiatData in
            self?.fiatData = fiatData
            group.leave()
        }
        
        if !firstAssetId.isEmpty, !secondAssetId.isEmpty {
            group.enter()
            apyService?.getApy(for: firstAssetId, targetAssetId: secondAssetId) { [weak self] apy in
                self?.apy = apy
                group.leave()
            }
        }
        
        group.enter()
        feeProvider.getFee(for: .liquidityRemoval) { [weak self] fee in
            self?.fee = fee
            group.leave()
        }
        
        group.enter()
        farmingService.getFarmedPools(baseAssetId: poolInfo?.baseAssetId, targetAssetId: poolInfo?.targetAssetId) { [weak self] pools in
            self?.stakedPools = pools
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self, let poolInfo = self.poolInfo else { return }
            
            self.warningViewModel = self.warningViewModelFactory.poolShareStackedViewModel(isHidden: self.stakedPools.isEmpty)

            self.details = self.detailsFactory.createRemoveLiquidityViewModels(with: self.inputedFirstAmount,
                                                                               targetAssetAmount: self.inputedSecondAmount,
                                                                               pool: poolInfo,
                                                                               apy: self.apy,
                                                                               fiatData: self.fiatData,
                                                                               focusedField: self.focusedField,
                                                                               slippageTolerance: self.slippageTolerance,
                                                                               isPresented: self.isPairPresented,
                                                                               isEnabled: self.isPairEnabled,
                                                                               fee: self.fee,
                                                                               viewModel: self)
        }
    }
    
    private func updateButtonState() {
        if inputedFirstAmount == .zero || inputedSecondAmount == .zero {
            view?.setupButton(isEnabled: false)
            return
        }

        view?.setupButton(isEnabled: true)
    }
}

