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
import SoraFoundation
import sorawallet

final class SupplyLiquidityViewModel {
    var detailsItem: PoolDetailsItem?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    weak var apyService: APYServiceProtocol?
    weak var fiatService: FiatServiceProtocol?
    weak var view: LiquidityViewProtocol?
    var wireframe: LiquidityWireframeProtocol?
    var poolsService: PoolsServiceInputProtocol?
    let assetManager: AssetManagerProtocol?
    let detailsFactory: DetailViewModelFactoryProtocol
    
    let debouncer = Debouncer(interval: 0.8)
    
    var title: String? {
        return R.string.localizable.commonSupplyLiquidityTitle(preferredLanguages: .currentLocale)
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
                updateBalanceData()
                if !firstAssetId.isEmpty, !secondAssetId.isEmpty {
                    poolInfo = await poolsService?.getPool(by: firstAssetId, targetAssetId: secondAssetId)
                }
                view?.setAccessoryView(isHidden: false)
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
                updateBalanceData()
                if !firstAssetId.isEmpty, !secondAssetId.isEmpty {
                    poolInfo = await poolsService?.getPool(by: firstAssetId, targetAssetId: secondAssetId)
                }
                view?.setAccessoryView(isHidden: false)
                recalculate(field: .two)
            }
        }
    }
    
    var inputedFirstAmount: Decimal = 0 {
        didSet {
            let inputedFiatText = setupInputedFiatText(from: inputedFirstAmount, assetId: firstAssetId)
            let text = isEnoughtFirstAssetLiquidity ? inputedFiatText : R.string.localizable.commonNotEnoughBalance(preferredLanguages: .currentLocale)
            let amountColor: SoramitsuColor = isEnoughtFirstAssetLiquidity ? .fgPrimary : .statusError
            let fiatColor: SoramitsuColor = isEnoughtFirstAssetLiquidity ? .fgSecondary : .statusError
            var state: InputFieldState = focusedField == .one ? .focused : .default
            state = isEnoughtFirstAssetLiquidity ? state : .fail
            
            view?.updateFirstAsset(state: state, amountColor: amountColor, fiatColor: fiatColor)
            view?.updateFirstAsset(fiatText: text)
        }
    }
    
    var inputedSecondAmount: Decimal = 0 {
        didSet {
            let inputedFiatText = setupInputedFiatText(from: inputedSecondAmount, assetId: secondAssetId)
            let text = isEnoughtSecondAssetLiquidity ? inputedFiatText : R.string.localizable.commonNotEnoughBalance(preferredLanguages: .currentLocale)
            let amountColor: SoramitsuColor = isEnoughtSecondAssetLiquidity ? .fgPrimary : .statusError
            let fiatColor: SoramitsuColor = isEnoughtSecondAssetLiquidity ? .fgSecondary : .statusError
            var state: InputFieldState = focusedField == .two ? .focused : .default
            state = isEnoughtSecondAssetLiquidity ? state : .fail
            
            view?.updateSecondAsset(state: state, amountColor: amountColor, fiatColor: fiatColor)
            view?.updateSecondAsset(fiatText: text)
        }
    }
    
    var slippageTolerance: Float = 0.5 {
        didSet {
            let slippageToleranceText = "\(slippageTolerance)%"
            view?.update(slippageTolerance: slippageToleranceText)
        }
    }
    
    var focusedField: FocusedField = .one {
        didSet {
            if focusedField == .one {
                view?.setAccessoryView(isHidden: firstAssetId.isEmpty)
            }
            if focusedField == .two {
                view?.setAccessoryView(isHidden: secondAssetId.isEmpty)
            }
        }
    }
    private let feeProvider: FeeProviderProtocol
    private var apy: Decimal?
    private var fiatData: [FiatData] = [] {
        didSet {
            updateBalanceData()
        }
    }

    private var fee: Decimal = 0 {
        didSet {
            let feeAssetSymbol = assetManager?.getAssetList()?.first { $0.isFeeAsset }?.symbol ?? ""
            warningViewModel = warningViewModelFactory.insufficientBalanceViewModel(feeAssetSymbol: feeAssetSymbol, feeAmount: fee)
        }
    }
    
    private var isPairEnabled: Bool = true
    private var isPairPresented: Bool = true
    private var transactionType: TransactionType = .liquidityAdd {
        didSet {
            feeProvider.getFee(for: transactionType) { [weak self] fee in
                self?.fee = fee
            }
        }
    }
    private let operationFactory: WalletNetworkOperationFactoryProtocol
    private weak var assetsProvider: AssetProviderProtocol?
    private var marketCapService: MarketCapServiceProtocol
    
    private var warningViewModelFactory: WarningViewModelFactory
    private var warningViewModel: WarningViewModel? {
        didSet {
            guard let warningViewModel else { return }
            view?.updateWarinignView(model: warningViewModel)
        }
    }
    
    private lazy var firstLiquidityProviderWarningViewModel: WarningViewModel? = warningViewModelFactory.firstLiquidityProviderViewModel() {
        didSet {
            guard let firstLiquidityProviderWarningViewModel else { return }
            view?.updateFirstLiquidityWarinignView(model: firstLiquidityProviderWarningViewModel)
        }
    }
    
    private var isEnoughtFirstAssetLiquidity: Bool {
        return inputedFirstAmount + fee <= firstAssetBalance.balance.decimalValue
    }
    
    private var isEnoughtSecondAssetLiquidity: Bool {
        return inputedSecondAmount <= secondAssetBalance.balance.decimalValue
    }
    
    init(
        wireframe: LiquidityWireframeProtocol?,
        poolInfo: PoolInfo?,
        fiatService: FiatServiceProtocol?,
        apyService: APYServiceProtocol?,
        poolsService: PoolsServiceInputProtocol?,
        assetManager: AssetManagerProtocol?,
        detailsFactory: DetailViewModelFactoryProtocol,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol?,
        warningViewModelFactory: WarningViewModelFactory = WarningViewModelFactory(),
        marketCapService: MarketCapServiceProtocol
    ) {
        self.poolInfo = poolInfo
        self.fiatService = fiatService
        self.apyService = apyService
        self.wireframe = wireframe
        self.poolsService = poolsService
        self.assetManager = assetManager
        self.detailsFactory = detailsFactory
        self.feeProvider = FeeProvider()
        self.operationFactory = operationFactory
        self.assetsProvider = assetsProvider
        self.warningViewModelFactory = warningViewModelFactory
        self.marketCapService = marketCapService
    }
}

extension SupplyLiquidityViewModel: LiquidityViewModelProtocol {
    func didSelect(variant: Float) {
        if focusedField == .one {
            guard firstAssetBalance.balance.decimalValue > 0 else { return }
            let isFeeAsset = assetManager?.assetInfo(for: firstAssetId)?.isFeeAsset ?? false
            let value = firstAssetBalance.balance.decimalValue * (Decimal(string: "\(variant)") ?? 0)
            inputedFirstAmount = isFeeAsset ? value - fee : value
            let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            view?.set(firstAmountText: formatter.stringFromDecimal(inputedFirstAmount) ?? "")
        }
        
        if focusedField == .two {
            guard secondAssetBalance.balance.decimalValue > 0 else { return }
            let isFeeAsset = assetManager?.assetInfo(for: secondAssetId)?.isFeeAsset ?? false
            let value = secondAssetBalance.balance.decimalValue * (Decimal(string: "\(variant)") ?? 0)
            inputedSecondAmount = isFeeAsset ? value - fee : value
            let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            view?.set(secondAmountText: formatter.stringFromDecimal(inputedSecondAmount) ?? "")
        }

        recalculate(field: focusedField)
    }
    
    func viewDidLoad() {
        feeProvider.getFee(for: transactionType) { [weak self] fee in
            guard let self else { return }

            self.fee = fee
            
            if !self.secondAssetId.isEmpty {
                self.view?.focus(field: .one)
            }
        }
        
        if let firstAssetId = poolInfo?.baseAssetId {
            self.firstAssetId = firstAssetId
        }
        
        if let secondAssetId = poolInfo?.targetAssetId {
            self.secondAssetId = secondAssetId
        }
        
        slippageTolerance = 0.5
        
        updateBalanceData()
        
        Task { [weak self] in
            self?.fiatData = await self?.fiatService?.getFiat() ?? []
        }

        assetsProvider?.add(observer: self)
    }
    
    func infoButtonTapped() {
        wireframe?.present(
            message: R.string.localizable.addLiquidityAlertText(preferredLanguages: .currentLocale),
            title: R.string.localizable.addLiquidityTitle(preferredLanguages: .currentLocale),
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
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
              let xstUsdAsset = assetManager.assetInfo(for: WalletAssetId.xstusd.rawValue),
              let kxorAsset = assetManager.assetInfo(for: WalletAssetId.kxor)
        else { return }

        var acceptableAssets = [xorAsset, kxorAsset]
        
        if secondAssetId != WalletAssetId.xst.rawValue {
            acceptableAssets.append(xstUsdAsset)
        }
        
        let assets = acceptableAssets.filter { $0.identifier != secondAssetId }
        
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
        guard
            let assetManager = assetManager,
            let fiatService = fiatService,
            let ethAsset = assetManager.assetInfo(for: WalletAssetId.eth),
            var assets = assetManager.getAssetList()?.filter({ asset in
                let assetId = asset.identifier
                
                let assetFilter = assetId != firstAssetId
                
                let unAcceptableAssetIds = [WalletAssetId.xor.rawValue, WalletAssetId.xstusd.rawValue]
                
                return assetFilter && !unAcceptableAssetIds.contains(assetId)
            }) else { return }
        
        if firstAssetId == WalletAssetId.kxor {
            assets = [ ethAsset ]
        }

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
        guard !firstAssetId.isEmpty,
              !secondAssetId.isEmpty,
              let fiatService = fiatService,
              let assetManager = assetManager else { return }
        wireframe?.showSupplyLiquidityConfirmation(on: view?.controller.navigationController,
                                                   baseAssetId: firstAssetId,
                                                   targetAssetId: secondAssetId,
                                                   fiatService: fiatService,
                                                   poolsService: poolsService,
                                                   assetManager: assetManager,
                                                   firstAssetAmount: inputedFirstAmount,
                                                   secondAssetAmount: inputedSecondAmount,
                                                   slippageTolerance: slippageTolerance,
                                                   details: details,
                                                   transactionType: transactionType,
                                                   fee: fee,
                                                   operationFactory: operationFactory)
    }
    
    func recalculate(field: FocusedField) {
        if focusedField == .one {
            if let poolInfo = poolInfo, let baseAssetPooled = poolInfo.baseAssetPooledTotal, baseAssetPooled > 0 {
                let targetAssetPooled = poolInfo.targetAssetPooledTotal ?? 0
                let scale = targetAssetPooled / baseAssetPooled
                inputedSecondAmount = inputedFirstAmount * scale
            }

            let formatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            view?.set(secondAmountText: formatter.stringFromDecimal(inputedSecondAmount) ?? "")
            
        } else {
            if let poolInfo = poolInfo, let targetAssetPooled = poolInfo.targetAssetPooledTotal, targetAssetPooled > 0 {
                let baseAssetPooled = poolInfo.baseAssetPooledTotal ?? 0
                let scale =  baseAssetPooled / targetAssetPooled
                inputedFirstAmount = inputedSecondAmount * scale
            }

            let formatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: secondAssetId)?.precision ?? 0)
            view?.set(firstAmountText: formatter.stringFromDecimal(inputedFirstAmount) ?? "")
        }
        
        debouncer.perform { [weak self] in
            self?.updateDetails { [weak self] in
                self?.updateButtonState()
            }
        }
    }
}

extension SupplyLiquidityViewModel: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        updateBalanceData()
    }
}

extension SupplyLiquidityViewModel {
    
    func updateBalanceData() {
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
    
    func setupInputedFiatText(from inputedAmount: Decimal, assetId: String) -> String {
        guard let asset = assetManager?.assetInfo(for: assetId) else { return "" }
        
        var fiatText = ""
        
        if let usdPrice = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = inputedAmount * usdPrice
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        return fiatText
    }
    
    func updatePairInfo() {
        guard !firstAssetId.isEmpty, !secondAssetId.isEmpty else {
            return
        }
        
        let group = DispatchGroup()

        group.enter()
        poolsService?.isPairPresentedInNetwork(baseAssetId: firstAssetId,
                                               targetAssetId: secondAssetId,
                                               accountId: "",
                                               completion: { [weak self] isPresented in
            self?.isPairPresented = isPresented
            group.leave()
        })
        
        group.enter()
        poolsService?.isPairEnabled(baseAssetId: firstAssetId,
                                    targetAssetId: secondAssetId,
                                    accountId: "",
                                    completion: { [weak self] isEnabled in
            self?.isPairEnabled = isEnabled
            group.leave()
        })
        
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            var isNeedWarning = false

            if !self.isPairPresented && !self.isPairEnabled {
                isNeedWarning = true
                self.transactionType = .liquidityAddNewPool
            }

            if self.isPairPresented && !self.isPairEnabled {
                isNeedWarning = true
                self.transactionType = .liquidityAddToExistingPoolFirstTime
            }

            self.firstLiquidityProviderWarningViewModel?.isHidden = !isNeedWarning
        }
    }
    
    func updateDetails(completion: (() -> Void)? = nil) {
        guard inputedFirstAmount > 0, inputedSecondAmount > 0 else { return }
        
        Task { [weak self] in
            guard let self else { return }

            async let apy = apyService?.getApy(for: firstAssetId, targetAssetId: secondAssetId)
            async let fee = feeProvider.getFee(for: transactionType)

            let results = await (apy: apy, fee: fee)

            self.apy = results.apy
            self.fee = results.fee
            
            if let fromAsset = self.assetManager?.assetInfo(for: self.firstAssetId), fromAsset.isFeeAsset {
                self.warningViewModel?.isHidden = self.firstAssetBalance.balance.decimalValue - self.inputedFirstAmount - self.fee > self.fee
            }
            
            let basedAmount = self.focusedField == .one ? self.inputedFirstAmount : self.inputedSecondAmount
            let targetAmount = self.focusedField == .one ? self.inputedSecondAmount : self.inputedFirstAmount
                                    
            self.details = self.detailsFactory.createSupplyLiquidityViewModels(with: basedAmount,
                                                                               targetAssetAmount: targetAmount,
                                                                               pool: self.poolInfo,
                                                                               apy: self.apy,
                                                                               fiatData: self.fiatData,
                                                                               focusedField: self.focusedField,
                                                                               slippageTolerance: self.slippageTolerance,
                                                                               isPresented: self.isPairPresented,
                                                                               isEnabled: self.isPairEnabled,
                                                                               fee: self.fee,
                                                                               viewModel: self)
            completion?()
        }
    }
    
    private func updateButtonState() {
        if firstAssetId.isEmpty || secondAssetId.isEmpty  {
            view?.setupButton(isEnabled: false)
            return
        }
        
        if (!firstAssetId.isEmpty && inputedFirstAmount == .zero) || (!secondAssetId.isEmpty && inputedSecondAmount == .zero) {
            view?.setupButton(isEnabled: false)
            return
        }
        
        if !isEnoughtFirstAssetLiquidity {
            view?.setupButton(isEnabled: false)
            return
        }
        
        if !isEnoughtSecondAssetLiquidity {
            view?.setupButton(isEnabled: false)
            return
        }

        view?.setupButton(isEnabled: true)
    }
}

