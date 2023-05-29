import UIKit
import SCard
import SoraUIKit
import CommonWallet
import RobinHood
import XNetworking

protocol AssetDetailsViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func viewDidLoad()
}

final class AssetDetailsViewModel {
    
    var balanceItems: [SoramitsuTableViewItemProtocol] = []
    var activityItem: RecentActivityItem?
    var pooledItem: PooledItem?
    
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    weak var assetManager: AssetManagerProtocol?
    var assetViewModelFactory: AssetViewModelFactoryProtocol
    let historyService: HistoryServiceProtocol
    let viewModelFactory: ActivityViewModelFactoryProtocol
    weak var fiatService: FiatServiceProtocol?
    let debouncer = Debouncer(interval: 0.5)
    let eventCenter: EventCenterProtocol
    
    weak var view: AssetDetailsViewProtocol?
    var wireframe: AssetDetailsWireframeProtocol?
    var poolsService: PoolsServiceInputProtocol?
    var assetInfo: AssetInfo
    var poolViewModelsFactory: PoolViewModelFactoryProtocol
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
    
    init(
        wireframe: AssetDetailsWireframeProtocol?,
        assetInfo: AssetInfo,
        assetViewModelFactory: AssetViewModelFactoryProtocol,
        assetManager: AssetManagerProtocol?,
        historyService: HistoryServiceProtocol,
        fiatService: FiatServiceProtocol,
        viewModelFactory: ActivityViewModelFactoryProtocol,
        eventCenter: EventCenterProtocol,
        poolsService: PoolsServiceInputProtocol?,
        poolViewModelsFactory: PoolViewModelFactoryProtocol,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        providerFactory: BalanceProviderFactory,
        accountId: String,
        address: String,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
        qrEncoder: WalletQREncoderProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        referralFactory: ReferralsOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol?
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
                self.updateActivityTtems(with: transactions) { item in
                    
                    self.activityItem?.historyViewModels = item.historyViewModels
                    if let activityTtem = self.activityItem {
                        self.reloadItems?([ activityTtem ])
                    }
                    
                }
            case .failure:
                break
            }
        }
    }
}

private extension AssetDetailsViewModel {
    func updateContent() {
        let group = DispatchGroup()
        
        group.enter()
        updateContent {
            group.leave()
        }
        
        group.enter()
        historyService.getHistory(count: 3, assetId: assetInfo.assetId) { [weak self] result in
            
            switch result {
            case .success(let transactions):
                if transactions.isEmpty {
                    group.leave()
                    return
                }
                
                self?.updateActivityTtems(with: transactions) { item in
                    self?.activityItem = item
                    group.leave()
                }
            case .failure:
                group.leave()
            }
        }
        
        if assetInfo.isFeeAsset {
            group.enter()
            guard let operation = referralFactory.createReferrerBalancesOperation() else { return }
            operation.completionBlock = { [weak self] in
                do {
                    guard let data = try operation.extractResultData()?.underlyingValue else {
                        group.leave()
                        return
                    }
                    self?.referralBalance = Decimal.fromSubstrateAmount(data.value, precision: 18) ?? Decimal(0)
                    group.leave()
                } catch {
                    Logger.shared.error("Request unsuccessful")
                }
            }
            OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .transient)
        }
        
        group.enter()
        poolsService?.loadPools(currentAsset: assetInfo, completion: { [weak self] pools in
            if pools.isEmpty {
                group.leave()
                return
            }

            self?.updatePooledtem(with: pools) { [weak self] in self?.pooledItem = $0 }
            group.leave()
        })
        
        group.notify(queue: .main) { [weak self] in
            self?.setupContent()
        }
    }
    
    func updateBalanceItems(with balance: BalanceData, itemCompletion: @escaping ([SoramitsuTableViewItemProtocol]) -> Void) {
        fiatService?.getFiat { [weak self] fiatData in
            self?.fiatData = fiatData

            guard let assetInfo = self?.assetManager?.assetInfo(for: balance.identifier),
                  let viewModel = self?.assetViewModelFactory.createAssetViewModel(with: assetInfo, fiatData: fiatData, mode: .view) else {
                return
            }

            var fiatBalanceText = ""
            if let usdPrice = fiatData.first(where: { $0.id == balance.identifier })?.priceUsd?.decimalValue {
                let fiatDecimal = balance.balance.decimalValue * usdPrice
                fiatBalanceText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
            }

            let transferableItem = TransferableItem(assetInfo: assetInfo,
                                                    fiat: fiatBalanceText,
                                                    balance: Amount(value: balance.balance.decimalValue))
            transferableItem.actionHandler = { type in
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
                                             sharingFactory: self.sharingFactory)
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
                        selectedTokenId: assetInfo.identifier,
                        assetManager: assetManager,
                        fiatService: fiatService,
                        networkFacade: networkFacade,
                        polkaswapNetworkFacade: self.polkaswapNetworkFacade,
                        assetsProvider: self.assetsProvider)
                case .buy:
                    guard let scard = SCard.shared else { return }
                    self.wireframe?.showXOne(on: self.view?.controller, address: self.address, service: scard)
                }
            }

            let items: [SoramitsuTableViewItemProtocol] = [ PriceItem(assetInfo: assetInfo, assetViewModel: viewModel),
                                                            SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)),
                                                            transferableItem ]
            itemCompletion(items)
        }
    }
    
    func updateActivityTtems(with transactions: [Transaction], completion: @escaping (RecentActivityItem) -> Void) {
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
        
        completion(recentActivityItem)
    }
    
    func updatePooledtem(with pools: [PoolInfo], completion: @escaping (PooledItem) -> Void) {
        fiatService?.getFiat { [weak self] fiatData in
            guard let self = self else {
                return
            }
            let viewModels = pools.compactMap { self.poolViewModelsFactory.createPoolViewModel(with: $0, fiatData: fiatData, mode: .view) }

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
                                                assetsProvider: self.assetsProvider)
            }
            completion(item)
        }
    }
    
    func updateContent(completion: (() -> Void)?) {
        guard let balance = assetsProvider?.getBalances(with: [assetInfo.identifier]).first else { return }
        
        if let context = balance.context {
            self.balanceContext = BalanceContext(context: context)
        }
        
        self.updateBalanceItems(with: balance) { balanceTtems in
            
            guard !self.balanceItems.isEmpty else {
                self.balanceItems = balanceTtems
                completion?()
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
    
    func setupContent() {
        let spacer: SoramitsuTableViewItemProtocol = SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear))
        
        var activityItems: [SoramitsuTableViewItemProtocol] = []
        if let activityItem = activityItem {
            activityItems = [ spacer, activityItem ]
        }
        
        var pooledItems: [SoramitsuTableViewItemProtocol] = []
        if let pooledItem = pooledItem {
            pooledItems = [ spacer, pooledItem ]
        }
        
        let assetIdItem = AssetIdItem(assetId: assetInfo.assetId, tapHandler: { [weak self] in
            let title = NSAttributedString(string: R.string.localizable.assetDetailsAssetIdCopied(preferredLanguages: .currentLocale))
            let viewModel = AppEventViewController.ViewModel(title: title)
            let appEventController = AppEventViewController(style: .custom(viewModel))
            self?.appEventService.showToasterIfNeeded(viewController: appEventController)
            UIPasteboard.general.string = self?.assetInfo.assetId
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
