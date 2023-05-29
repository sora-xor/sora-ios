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
        return R.string.localizable.commonRemoveLiquidity(preferredLanguages: .currentLocale)
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
            guard let asset = assetManager?.assetInfo(for: firstAssetId) else { return }
            let image = RemoteSerializer.shared.image(with: asset.icon ?? "")
            view?.updateFirstAsset(symbol: asset.symbol, image: image)
            setupBalanceDataProvider()
            if !firstAssetId.isEmpty, !secondAssetId.isEmpty {
                poolInfo = poolsService?.getPool(by: firstAssetId, targetAssetId: secondAssetId)
            }
            recalculate(field: .one)
        }
    }
    
    var secondAssetId: String = "" {
        didSet {
            guard let asset = assetManager?.assetInfo(for: secondAssetId) else { return }
            let image = RemoteSerializer.shared.image(with: asset.icon ?? "")
            view?.updateSecondAsset(symbol: asset.symbol, image: image)
            setupBalanceDataProvider()
            if !firstAssetId.isEmpty, !secondAssetId.isEmpty {
                poolInfo = poolsService?.getPool(by: firstAssetId, targetAssetId: secondAssetId)
            }
            recalculate(field: .two)
        }
    }
    
    var inputedFirstAmount: Decimal = 0 {
        didSet {
            guard let poolInfo = poolInfo, let firstAssetPooled = poolInfo.baseAssetPooledByAccount else { return }
            let formatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            
            if firstAssetPooled  <= inputedFirstAmount {
                inputedFirstAmount = firstAssetPooled
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
            guard let poolInfo = poolInfo, let secondAssetPooled = poolInfo.targetAssetPooledByAccount else { return }
            let formatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: secondAssetId)?.precision ?? 0)
            
            if secondAssetPooled  <= inputedFirstAmount {
                inputedSecondAmount = secondAssetPooled
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
    private let feeProvider: FeeProviderProtocol
    private var fiatData: [FiatData] = [] {
        didSet {
            setupBalanceDataProvider()
        }
    }
    private var apy: SbApyInfo?
    private var fee: Decimal = 0
    
    private var isPairEnabled: Bool = true
    private var isPairPresented: Bool = true
    
    private weak var assetsProvider: AssetProviderProtocol?
    
    init(
        wireframe: LiquidityWireframeProtocol?,
        poolInfo: PoolInfo,
        apyService: APYServiceProtocol?,
        fiatService: FiatServiceProtocol?,
        poolsService: PoolsServiceInputProtocol?,
        assetManager: AssetManagerProtocol?,
        detailsFactory: DetailViewModelFactoryProtocol,
        providerFactory: BalanceProviderFactory,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol?
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
    }
}

extension RemoveLiquidityViewModel: LiquidityViewModelProtocol {
    func didSelect(variant: Float) {
        if focusedField == .one {
            guard let poolInfo = poolInfo, let firstAssetPooled = poolInfo.baseAssetPooledByAccount else { return }
            let value = firstAssetPooled * (Decimal(string: "\(variant)") ?? 0)
            let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            view?.set(firstAmountText: formatter.stringFromDecimal(value) ?? "")
            inputedFirstAmount = value
        }
        
        if focusedField == .two {
            guard let poolInfo = poolInfo, let secondAssetPooled = poolInfo.targetAssetPooledByAccount else { return }
            let value = secondAssetPooled * (Decimal(string: "\(variant)") ?? 0)
            let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: secondAssetId)?.precision ?? 0)
            view?.set(secondAmountText: formatter.stringFromDecimal(value) ?? "")
            inputedSecondAmount = value
        }
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
            title: R.string.localizable.poolApyTitle(),
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
                                       assetIds: assets.map { $0.identifier }) { [weak self] assetId in
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
                                       assetIds: assets.map { $0.identifier }) { [weak self] assetId in
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
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self, let poolInfo = self.poolInfo else { return }
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

