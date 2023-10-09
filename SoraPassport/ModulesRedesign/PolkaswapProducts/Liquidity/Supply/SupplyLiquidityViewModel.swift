import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import SoraFoundation
import XNetworking

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
            guard let asset = assetManager?.assetInfo(for: firstAssetId) else { return }
            let image = RemoteSerializer.shared.image(with: asset.icon ?? "")
            view?.updateFirstAsset(symbol: asset.symbol, image: image)
            setupBalanceDataProvider()
            if !firstAssetId.isEmpty, !secondAssetId.isEmpty {
                poolInfo = poolsService?.getPool(by: firstAssetId, targetAssetId: secondAssetId)
            }
            view?.setAccessoryView(isHidden: false)
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
            view?.setAccessoryView(isHidden: false)
            recalculate(field: .two)
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
    private var apy: SbApyInfo?
    private var fiatData: [FiatData] = [] {
        didSet {
            setupBalanceDataProvider()
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
    private var transactionType: TransactionType = .liquidityAdd
    private let operationFactory: WalletNetworkOperationFactoryProtocol
    private weak var assetsProvider: AssetProviderProtocol?
    private let regex = try? NSRegularExpression(pattern: "0[xX]03[0-9a-fA-F]+")
    
    private var warningViewModelFactory: WarningViewModelFactory
    private var warningViewModel: WarningViewModel? {
        didSet {
            guard let warningViewModel else { return }
            view?.updateWarinignView(model: warningViewModel)
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
        warningViewModelFactory: WarningViewModelFactory = WarningViewModelFactory()
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
        if let firstAssetId = poolInfo?.baseAssetId {
            self.firstAssetId = firstAssetId
        }
        
        if let secondAssetId = poolInfo?.targetAssetId {
            self.secondAssetId = secondAssetId
        }

        slippageTolerance = 0.5
        assetsProvider?.add(observer: self)
        if !secondAssetId.isEmpty {
            view?.focus(field: .one)
        }
        
        fiatService?.getFiat { [weak self] fiatData in
            self?.fiatData = fiatData
        }
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
            title: "",
            closeAction: R.string.localizable.commonOk(),
            from: view
        )
    }
    
    func choiсeBaseAssetButtonTapped() {
        guard let assetManager = assetManager,
              let fiatService = fiatService,
              let xorAsset = assetManager.assetInfo(for: WalletAssetId.xor.rawValue),
              let xstUsdAsset = assetManager.assetInfo(for: WalletAssetId.xstusd.rawValue) else { return }

        var acceptableAssets = [xorAsset]
        
        if secondAssetId != WalletAssetId.xst.rawValue {
            acceptableAssets.append(xstUsdAsset)
        }
        
        let assets = acceptableAssets.filter({ asset in
            let assetId = asset.identifier
            let range = NSRange(location: 0, length: assetId.count)
            return assetId != secondAssetId && regex?.firstMatch(in: assetId, range: range) == nil
        })
        
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
        guard let assetManager = assetManager,
              let fiatService = fiatService,
              let assets = assetManager.getAssetList()?.filter({ asset in
                  let assetId = asset.identifier
                  
                  var assetFilter = assetId != firstAssetId
                  
                  var unAcceptableAssetIds = [WalletAssetId.xor.rawValue, WalletAssetId.xstusd.rawValue]

                  if firstAssetId == WalletAssetId.xstusd.rawValue {
                      unAcceptableAssetIds.append(WalletAssetId.xst.rawValue)
                  }
                  
                  assetFilter = assetFilter && !unAcceptableAssetIds.contains(assetId)
                  
                  let range = NSRange(location: 0, length: assetId.count)
                  return assetFilter && regex?.firstMatch(in: assetId, range: range) == nil
              }) else { return }

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
        
        updateButtonState()
        debouncer.perform { [weak self] in
            self?.updateDetails()
        }
    }
}

extension SupplyLiquidityViewModel: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        setupBalanceDataProvider()
    }
}

extension SupplyLiquidityViewModel {
    
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
        guard self.inputedFirstAmount > 0, self.inputedSecondAmount > 0 else { return }

        if !isPairPresented && !isPairEnabled {
            transactionType = .liquidityAddNewPool
        }
        
        if isPairPresented && !isPairEnabled {
            transactionType = .liquidityAddToExistingPoolFirstTime
        }
        
        let group = DispatchGroup()
        
        if !firstAssetId.isEmpty,
            !secondAssetId.isEmpty,
            transactionType != .liquidityAddNewPool,
            transactionType != .liquidityAddToExistingPoolFirstTime {
            group.enter()
            apyService?.getApy(for: firstAssetId, targetAssetId: secondAssetId) { [weak self] apy in
                self?.apy = apy
                group.leave()
            }
        }

        group.enter()
        feeProvider.getFee(for: transactionType) { [weak self] fee in
            self?.fee = fee
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
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

