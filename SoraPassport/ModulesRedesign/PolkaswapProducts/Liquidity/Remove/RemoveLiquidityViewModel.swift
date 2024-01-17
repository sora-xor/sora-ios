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
import sorawallet

final class RemoveLiquidityViewModel {
    @Published var snapshot: PolkaswapSnapshot = PolkaswapSnapshot()
    var snapshotPublisher: Published<PolkaswapSnapshot>.Publisher { $snapshot }
    
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
    let itemFactory: PolkaswapItemFactory
    
    let debouncer = Debouncer(interval: 0.8)
    
    @Published var firstAsset: AssetProfile = AssetProfile()
    @Published var secondAsset: AssetProfile = AssetProfile()
    @Published var slippageToleranceText: String = ""
    @Published var selectedMarketText: String = ""
    @Published var reviewButtonTitle: String = ""
    @Published var isMiddleButtonEnabled: Bool = false
    @Published var isButtonEnabled: Bool = false
    @Published var isAccessoryViewHidden: Bool = false
    @Published var isNeedLoadingState: Bool = false
    @Published var isMarketLoadingState: Bool = false
    @Published var warningViewModel: WarningViewModel?
    @Published var firstLiquidityViewModel: WarningViewModel?
    @Published var details: [DetailViewModel]?

    var firstAssetPublisher: Published<AssetProfile>.Publisher { $firstAsset }
    var secondAssetPublisher: Published<AssetProfile>.Publisher { $secondAsset }
    var slippagePublisher: Published<String>.Publisher { $slippageToleranceText }
    var marketPublisher: Published<String>.Publisher { $selectedMarketText }
    var reviewButtonPublisher: Published<String>.Publisher { $reviewButtonTitle }
    var isMiddleButtonEnabledPublisher: Published<Bool>.Publisher { $isMiddleButtonEnabled }
    var isButtonEnabledPublisher: Published<Bool>.Publisher { $isButtonEnabled }
    var isAccessoryViewHiddenPublisher: Published<Bool>.Publisher { $isAccessoryViewHidden }
    var isNeedLoadingStatePublisher: Published<Bool>.Publisher { $isNeedLoadingState }
    var isMarketLoadingStatePublisher: Published<Bool>.Publisher { $isMarketLoadingState }
    var warningViewModelPublisher: Published<WarningViewModel?>.Publisher { $warningViewModel }
    var firstLiquidityViewModelPublisher: Published<WarningViewModel?>.Publisher { $firstLiquidityViewModel }
    var detailsPublisher: Published<[DetailViewModel]?>.Publisher { $details }
    
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
    
    var firstAssetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            setupFullBalanceText(from: firstAssetBalance) { [weak self] text in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.update(self.firstAsset, balance: text)
                }
            }
        }
    }
    
    var secondAssetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            setupFullBalanceText(from: secondAssetBalance) { [weak self] text in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.update(self.secondAsset, balance: text)
                }
            }
        }
    }
    
    var firstAssetId: String = "" {
        didSet {
            Task {
                guard let asset = assetManager?.assetInfo(for: firstAssetId) else { return }
                let image = RemoteSerializer.shared.image(with: asset.icon ?? "")
                update(firstAsset, symbol: asset.symbol, image: image)
                updateBalanceData()
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
                update(secondAsset, symbol: asset.symbol, image: image)
                updateBalanceData()
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
                set(firstAsset, amount: formatter.stringFromDecimal(inputedFirstAmount) ?? "")
            }

            setupInputedFiatText(from: inputedFirstAmount, assetId: firstAssetId) { [weak self] text in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let state: InputFieldState = self.focusedField == .one ? .focused : .default
                    self.update(self.firstAsset, state: state, amountColor: .fgPrimary, fiatColor: .fgSecondary)
                    self.update(self.firstAsset, fiat: text)
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
                set(secondAsset, amount: formatter.stringFromDecimal(inputedSecondAmount) ?? "")
            }

            setupInputedFiatText(from: inputedSecondAmount, assetId: secondAssetId) { [weak self] text in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let state: InputFieldState = self.focusedField == .two ? .focused : .default
                    self.update(self.secondAsset, state: state, amountColor: .fgPrimary, fiatColor: .fgSecondary)
                    self.update(self.secondAsset, fiat: text)
                }
            }
        }
    }
    
    var slippageTolerance: Float = 0.5 {
        didSet {
            let slippageToleranceText = "\(slippageTolerance)%"
            update(slippageTolerance: slippageToleranceText)
        }
    }
    
    var focusedField: FocusedField = .one
    
    private let feeProvider: FeeProviderProtocol
    private var fiatData: [FiatData] = [] {
        didSet {
            updateBalanceData()
        }
    }
    private var apy: Decimal?
    private var fee: Decimal = 0
    
    private var isPairEnabled: Bool = true
    private var isPairPresented: Bool = true
    
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
        return baseAssetPooledByAccount - baseAssetPooledByAccount * stackedPercentage
    }
    
    private var availableTargetAssetPooledByAccount: Decimal {
        guard let poolInfo = poolInfo, let targetAssetPooledByAccount = poolInfo.targetAssetPooledByAccount else { return .zero }
        return targetAssetPooledByAccount - targetAssetPooledByAccount * stackedPercentage
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
        marketCapService: MarketCapServiceProtocol,
        itemFactory: PolkaswapItemFactory
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
        self.farms = farms
        self.warningViewModelFactory = warningViewModelFactory
        self.marketCapService = marketCapService
        self.itemFactory = itemFactory
    }
}

extension RemoveLiquidityViewModel: LiquidityViewModelProtocol {
    func reload() {
        snapshot = createSnapshot()
    }
    
    private func createSnapshot() -> PolkaswapSnapshot {
        var snapshot = PolkaswapSnapshot()
        
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
        
    }
    
    private func contentSection() -> PolkaswapSection {
        var items: [PolkaswapSectionItem] = []
        
        let polkaswapItem = itemFactory.createPolkaswapItem(with: self)
        let detailsItem = itemFactory.createSwapDetailsItem(with: self)
        
        items.append(contentsOf: [
            .polkaswap(polkaswapItem),
            .space(SoramitsuTableViewSpacerItem(space: 8, color: .custom(uiColor: .clear))),
            .details(detailsItem)
        ])
        
        return PolkaswapSection(items: items)
    }
    
    func didSelect(variant: Float) {
        if focusedField == .one {
            guard poolInfo != nil else { return }
            let value = availableBaseAssetPooledByAccount * (Decimal(string: "\(variant)") ?? 0)
            let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            set(firstAsset, amount: formatter.stringFromDecimal(value) ?? "")
            inputedFirstAmount = value
        }
        
        if focusedField == .two {
            guard poolInfo != nil else { return }
            let value = availableTargetAssetPooledByAccount * (Decimal(string: "\(variant)") ?? 0)
            let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: secondAssetId)?.precision ?? 0)
            set(secondAsset, amount: formatter.stringFromDecimal(value) ?? "")
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
        slippageTolerance = 0.5
        assetsProvider?.add(observer: self)
        focus(field: .one)
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
        guard let poolInfo = poolInfo, let assetManager = assetManager, let details = details else { return }
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
            set(secondAsset, amount: formatter.stringFromDecimal(inputedSecondAmount) ?? "")
            updateButtonState()
            debouncer.perform { [weak self] in
                self?.updateDetails()
            }
        } else {
            let formatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: secondAssetId)?.precision ?? 0)
            let scale = (poolInfo.baseAssetPooledTotal ?? 0) / (poolInfo.targetAssetPooledTotal ?? 0)
            inputedFirstAmount = inputedSecondAmount * scale
            set(firstAsset, amount: formatter.stringFromDecimal(inputedFirstAmount) ?? "")
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
        Task { [weak self] in
            guard let self else { return }
            
            async let fiatData = self.fiatService?.getFiat()
            
            async let apy = self.apyService?.getApy(for: firstAssetId, targetAssetId: secondAssetId)
            async let fee = self.feeProvider.getFee(for: .liquidityRemoval)
            
            async let farms = self.farmingService.getUserFarmInfos(
                baseAssetId: self.poolInfo?.baseAssetId,
                targetAssetId: poolInfo?.targetAssetId
            )
            
            let results = await (fiatData: fiatData, apy: apy, fee: fee, farms: farms)

            self.fiatData = results.fiatData ?? []
            self.apy = results.apy
            self.fee = results.fee
            self.farms = results.farms
            
            guard let poolInfo = self.poolInfo else { return }
            
            self.warningViewModel = self.warningViewModelFactory.poolShareStackedViewModel(isHidden: self.farms.isEmpty)

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
            setupButton(isEnabled: false)
            return
        }

        setupButton(isEnabled: true)
    }
}

extension RemoveLiquidityViewModel {
    func update(_ asset: AssetProfile, state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor) {
        asset.state = state
        asset.amountColor = amountColor
        asset.fiatColor = fiatColor
    }
    
    func update(_ asset: AssetProfile, fiat: String) {
        asset.fiat = fiat
    }
    
    func update(_ asset: AssetProfile, balance: String) {
        asset.balance = balance
    }
    
    func update(_ asset: AssetProfile, symbol: String, image: UIImage?) {
        asset.symbol = symbol
        asset.image = image
    }
    
    func updateMiddleButton(isEnabled: Bool) {
        isMiddleButtonEnabled = isEnabled
    }
    
    func update(slippageTolerance: String) {
        slippageToleranceText = slippageTolerance
    }
    
    func update(selectedMarket: String) {
        selectedMarketText = selectedMarket
    }
    
    func set(_ asset: AssetProfile, amount: String) {
        asset.amount = amount
    }
    
    func setAccessoryView(isHidden: Bool) {
        isAccessoryViewHidden = isHidden
    }
    
    func update(isNeedLoadingState: Bool) {
        self.isNeedLoadingState = isNeedLoadingState
    }
    
    func focus(field: FocusedField) {
        switch field {
        case .one:
            firstAsset.isFirstResponder = true
        case .two:
            secondAsset.isFirstResponder = true
        }
    }
    
    func setupButton(isEnabled: Bool) {
        isButtonEnabled = isEnabled
    }
    
    func setupMarketButton(isLoadingState: Bool) {
        isMarketLoadingState = isLoadingState
    }
    
    func updateReviewButton(title: String) {
        reviewButtonTitle = title
    }
}

