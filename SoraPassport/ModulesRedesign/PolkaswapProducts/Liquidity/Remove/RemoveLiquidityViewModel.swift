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
            if let asset = assetManager?.assetInfo(for: firstAssetId) {
                let image = RemoteSerializer.shared.image(with: asset.icon ?? "")
                view?.updateFirstAsset(symbol: asset.symbol, image: image)
            }
            updateBalanceData()
            updatePairInfo()
            recalculate(field: .one)
        }
    }
    
    var secondAssetId: String = "" {
        didSet {
            if let asset = assetManager?.assetInfo(for: secondAssetId) {
                let image = RemoteSerializer.shared.image(with: asset.icon ?? "")
                view?.updateSecondAsset(symbol: asset.symbol, image: image)
            }
            updateBalanceData()
            updatePairInfo()
            recalculate(field: .two)
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
    
    var slippageTolerance: PolkaswapSlippage = .defaultValue {
        didSet {
            view?.update(slippageTolerance: slippageTolerance.displayValue)
            detailsTask?.cancel()
            detailsRequestId = nil
            fee = .zero
            debouncer.perform { [weak self] in
                self?.updateDetails()
            }
        }
    }
    
    var focusedField: FocusedField = .one
    
    private var warningViewModel: WarningViewModel? {
        didSet {
            guard let warningViewModel else { return }
            view?.updateWarinignView(model: warningViewModel)
        }
    }
    
    private var fiatData: [PIExactFiatData] = [] {
        didSet {
            updateBalanceData()
        }
    }
    private var apy: Decimal?
    private var fee: Decimal = 0 {
        didSet {
            updateButtonState()
        }
    }
    
    private var isPairEnabled = false
    private var isPairPresented = false
    private var isPairStateValid = false
    private var pairStateTask: Task<Void, Never>?
    private var pairStateRequestId: UUID?
    private var detailsTask: Task<Void, Never>?
    private var detailsRequestId: UUID?
    
    private weak var assetsProvider: AssetProviderProtocol?
    private let farmingService: DemeterFarmingServiceProtocol
    private var farms: [UserFarm] = []
    private var warningViewModelFactory: WarningViewModelFactory
    private var marketCapService: MarketCapServiceProtocol
    private var stackedPercentage: Decimal {
        return farms.map {
            let accountPoolBalance = poolInfo?.accountPoolBalance ?? .zero
            let pooledTokens = $0.pooledTokens ?? .zero
            return accountPoolBalance > 0 ? (pooledTokens / accountPoolBalance) : 0
        }.max() ?? Decimal.zero
    }
    
    private var availableBaseAssetPooledByAccount: Decimal {
        guard let poolInfo = poolInfo, let baseAssetPooledByAccount = poolInfo.baseAssetPooledByAccount else { return .zero }
        return max(
            .zero,
            baseAssetPooledByAccount - baseAssetPooledByAccount * stackedPercentage
        )
    }
    
    private var availableTargetAssetPooledByAccount: Decimal {
        guard let poolInfo = poolInfo, let targetAssetPooledByAccount = poolInfo.targetAssetPooledByAccount else { return .zero }
        return max(
            .zero,
            targetAssetPooledByAccount - targetAssetPooledByAccount * stackedPercentage
        )
    }

    private var isEnoughtFeeAssetLiquidity: Bool {
        guard fee > 0 else { return false }
        if firstAssetId == WalletAssetId.xor.rawValue {
            return firstAssetBalance.balance.decimalValue >= fee
        }
        if secondAssetId == WalletAssetId.xor.rawValue {
            return secondAssetBalance.balance.decimalValue >= fee
        }
        guard let xorBalance = assetsProvider?.getBalances(
            with: [WalletAssetId.xor.rawValue]
        ).first(where: { $0.identifier == WalletAssetId.xor.rawValue }) else {
            return false
        }
        return xorBalance.balance.decimalValue >= fee
    }
    
    init(
        wireframe: LiquidityWireframeProtocol?,
        poolInfo: PoolInfo,
        farms: [UserFarm],
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
        self.operationFactory = operationFactory
        self.assetsProvider = assetsProvider
        self.farmingService = farmingService
        self.farms = farms
        self.warningViewModelFactory = warningViewModelFactory
        self.marketCapService = marketCapService
    }

    deinit {
        pairStateTask?.cancel()
        detailsTask?.cancel()
    }
}

extension RemoveLiquidityViewModel: LiquidityViewModelProtocol {
    func didSelect(variant: Decimal) {
        if focusedField == .one {
            guard poolInfo != nil else { return }
            let value = availableBaseAssetPooledByAccount * variant
            let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            view?.set(firstAmountText: formatter.stringFromDecimal(value) ?? "")
            inputedFirstAmount = value
        }
        
        if focusedField == .two {
            guard poolInfo != nil else { return }
            let value = availableTargetAssetPooledByAccount * variant
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

        updateBalanceData()
        slippageTolerance = .defaultValue
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
        guard isPairStateValid,
              isPairPresented,
              isPairEnabled,
              fee > 0,
              isEnoughtFeeAssetLiquidity,
              inputedFirstAmount > 0,
              inputedSecondAmount > 0,
              let poolInfo = poolInfo,
              poolInfo.baseAssetId == firstAssetId,
              poolInfo.targetAssetId == secondAssetId,
              let poolsService = poolsService,
              let assetManager = assetManager else { return }
        wireframe?.showRemoveLiquidityConfirmation(on: view?.controller.navigationController,
                                                   poolInfo: poolInfo,
                                                   poolsService: poolsService,
                                                   assetManager: assetManager,
                                                   firstAssetAmount: inputedFirstAmount,
                                                   secondAssetAmount: inputedSecondAmount,
                                                   slippageTolerance: slippageTolerance,
                                                   details: details,
                                                   fee: fee,
                                                   operationFactory: operationFactory,
                                                   feeChangeHandler: { [weak self] in
                                                       self?.updateDetails()
                                                   },
                                                   completionHandler: completionHandler)
    }
    
    func recalculate(field: FocusedField) {
        detailsTask?.cancel()
        detailsRequestId = nil
        fee = .zero
        updateButtonState()

        guard let poolInfo = poolInfo,
              let basePooledTotal = poolInfo.baseAssetPooledTotal,
              basePooledTotal > 0,
              let targetPooledTotal = poolInfo.targetAssetPooledTotal,
              targetPooledTotal > 0 else {
            inputedFirstAmount = .zero
            inputedSecondAmount = .zero
            updateButtonState()
            return
        }

        if focusedField == .one {
            let formatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: secondAssetId)?.precision ?? 0)
            let scale = targetPooledTotal / basePooledTotal
            inputedSecondAmount = inputedFirstAmount * scale
            view?.set(secondAmountText: formatter.stringFromDecimal(inputedSecondAmount) ?? "")
            updateButtonState()
            debouncer.perform { [weak self] in
                self?.updateDetails()
            }
        } else {
            let formatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            let scale = basePooledTotal / targetPooledTotal
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
        updateBalanceData()
    }
}

extension RemoveLiquidityViewModel {
    
    func updateBalanceData() {
        if !firstAssetId.isEmpty {
            firstAssetBalance = assetsProvider?.getBalances(
                with: [firstAssetId]
            ).first(where: { $0.identifier == firstAssetId })
                ?? BalanceData(
                    identifier: firstAssetId,
                    balance: AmountDecimal(value: .zero)
                )
        }
        
        if !secondAssetId.isEmpty {
            secondAssetBalance = assetsProvider?.getBalances(
                with: [secondAssetId]
            ).first(where: { $0.identifier == secondAssetId })
                ?? BalanceData(
                    identifier: secondAssetId,
                    balance: AmountDecimal(value: .zero)
                )
        }
        updateButtonState()
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
        pairStateTask?.cancel()
        pairStateRequestId = nil
        detailsTask?.cancel()
        detailsRequestId = nil
        fee = .zero

        let baseAssetId = firstAssetId
        let targetAssetId = secondAssetId
        guard !baseAssetId.isEmpty,
              !targetAssetId.isEmpty,
              baseAssetId != targetAssetId,
              let poolsService else {
            isPairPresented = false
            isPairEnabled = false
            isPairStateValid = false
            updateButtonState()
            return
        }

        isPairPresented = false
        isPairEnabled = false
        isPairStateValid = false
        poolInfo = nil
        updateButtonState()

        let requestId = UUID()
        pairStateRequestId = requestId
        pairStateTask = Task { @MainActor [weak self, weak poolsService] in
            guard let poolsService else { return }
            do {
                let state = try await poolsService.loadPairState(
                    baseAssetId: baseAssetId,
                    targetAssetId: targetAssetId
                )
                guard state.isPresented,
                      state.isEnabled,
                      let livePool = await poolsService.loadPool(
                          by: baseAssetId,
                          targetAssetId: targetAssetId
                      ), livePool.baseAssetId == baseAssetId,
                      livePool.targetAssetId == targetAssetId else {
                    throw LiquidityConfirmationPreflightError.unavailable
                }

                try Task.checkCancellation()
                guard let self else { return }
                guard self.pairStateRequestId == requestId,
                      self.firstAssetId == baseAssetId,
                      self.secondAssetId == targetAssetId else {
                    return
                }

                self.pairStateRequestId = nil
                self.isPairPresented = true
                self.isPairEnabled = true
                self.isPairStateValid = true
                self.poolInfo = livePool
                self.farms = livePool.farms
                if self.inputedFirstAmount > 0 || self.inputedSecondAmount > 0 {
                    self.recalculate(field: self.focusedField)
                }
                self.updateButtonState()
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                guard !Task.isCancelled,
                      self.pairStateRequestId == requestId,
                      self.firstAssetId == baseAssetId,
                      self.secondAssetId == targetAssetId else {
                    return
                }
                self.pairStateRequestId = nil
                self.isPairPresented = false
                self.isPairEnabled = false
                self.isPairStateValid = false
                self.updateButtonState()
            }
        }
    }
    
    func updateDetails() {
        detailsTask?.cancel()
        detailsRequestId = nil
        fee = .zero
        guard isPairStateValid,
              isPairPresented,
              isPairEnabled,
              inputedFirstAmount > 0,
              inputedSecondAmount > 0,
              let poolSnapshot = poolInfo,
              poolSnapshot.baseAssetId == firstAssetId,
              poolSnapshot.targetAssetId == secondAssetId,
              let assetManager else {
            return
        }
        let baseAssetId = firstAssetId
        let targetAssetId = secondAssetId
        let firstAmount = inputedFirstAmount
        let secondAmount = inputedSecondAmount
        let focusedField = focusedField
        let slippageTolerance = slippageTolerance
        let transferInfo: TransferInfo
        do {
            transferInfo = try LiquidityTransferInfoFactory.removal(
                poolInfo: poolSnapshot,
                firstAssetAmount: firstAmount,
                secondAssetAmount: secondAmount,
                slippageTolerance: slippageTolerance,
                fee: .zero,
                assetManager: assetManager
            )
        } catch {
            return
        }
        let requestId = UUID()
        detailsRequestId = requestId

        detailsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                async let fiatData = self.fiatService?.getFiat()
                async let apy = self.apyService?.getApy(
                    for: baseAssetId,
                    targetAssetId: targetAssetId
                )
                async let exactFee = self.operationFactory.estimateLiquidityFee(for: transferInfo)
                let results = try await (fiatData: fiatData, apy: apy, fee: exactFee)

                guard !Task.isCancelled,
                      results.fee > 0,
                      self.detailsRequestId == requestId,
                      self.isPairStateValid,
                      self.isPairPresented,
                      self.isPairEnabled,
                      self.firstAssetId == baseAssetId,
                      self.secondAssetId == targetAssetId,
                      self.inputedFirstAmount == firstAmount,
                      self.inputedSecondAmount == secondAmount,
                      self.focusedField == focusedField,
                      self.slippageTolerance == slippageTolerance,
                      self.poolInfo?.baseAssetId == baseAssetId,
                      self.poolInfo?.targetAssetId == targetAssetId,
                      self.poolInfo?.baseAssetReserves == poolSnapshot.baseAssetReserves,
                      self.poolInfo?.targetAssetReserves == poolSnapshot.targetAssetReserves,
                      self.poolInfo?.totalIssuances == poolSnapshot.totalIssuances else {
                    return
                }

                self.fiatData = results.fiatData ?? []
                self.apy = results.apy
                self.fee = results.fee
                self.farms = poolSnapshot.farms
                self.warningViewModel = self.warningViewModelFactory
                    .poolShareStackedViewModel(isHidden: self.farms.isEmpty)

                self.details = self.detailsFactory.createRemoveLiquidityViewModels(
                    with: firstAmount,
                    targetAssetAmount: secondAmount,
                    pool: poolSnapshot,
                    apy: self.apy,
                    fiatData: self.fiatData,
                    focusedField: focusedField,
                    slippageTolerance: slippageTolerance,
                    isPresented: true,
                    isEnabled: true,
                    fee: results.fee,
                    viewModel: self
                )
            } catch is CancellationError {
                return
            } catch {
                guard self.detailsRequestId == requestId,
                      self.firstAssetId == baseAssetId,
                      self.secondAssetId == targetAssetId,
                      self.inputedFirstAmount == firstAmount,
                      self.inputedSecondAmount == secondAmount,
                      self.slippageTolerance == slippageTolerance else {
                    return
                }
                self.fee = .zero
            }
        }
    }
    
    private func updateButtonState() {
        guard isPairStateValid,
              isPairPresented,
              isPairEnabled,
              fee > 0,
              isEnoughtFeeAssetLiquidity,
              let poolInfo,
              poolInfo.baseAssetId == firstAssetId,
              poolInfo.targetAssetId == secondAssetId,
              inputedFirstAmount > .zero,
              inputedSecondAmount > .zero,
              inputedFirstAmount <= availableBaseAssetPooledByAccount,
              inputedSecondAmount <= availableTargetAssetPooledByAccount else {
            view?.setupButton(isEnabled: false)
            return
        }

        view?.setupButton(isEnabled: true)
    }
}
