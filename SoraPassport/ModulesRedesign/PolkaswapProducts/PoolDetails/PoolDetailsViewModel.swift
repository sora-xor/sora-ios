import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import SoraFoundation
import XNetworking

protocol PoolDetailsViewModelProtocol: AnyObject {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var dismiss: (() -> Void)? { get set }
    func viewDidLoad()
    func apyInfoButtonTapped()
    func infoButtonTapped(with type: Liquidity.TransactionLiquidityType)
    func dismissed()
}

final class PoolDetailsViewModel {
    var detailsItem: PoolDetailsItem?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var dismiss: (() -> Void)?
    var dismissHandler: (() -> Void)?
    
    var apyService: APYServiceProtocol
    var fiatService: FiatServiceProtocol
    weak var view: PoolDetailsViewProtocol?
    var wireframe: PoolDetailsWireframeProtocol?
    var poolsService: PoolsServiceInputProtocol?
    var poolInfo: PoolInfo {
        didSet {
            updateContent()
        }
    }
    let assetManager: AssetManagerProtocol
    let detailsFactory: DetailViewModelFactoryProtocol
    let providerFactory: BalanceProviderFactory
    let operationFactory: WalletNetworkOperationFactoryProtocol
    private var isDeletedPool = false
    private weak var assetsProvider: AssetProviderProtocol?
    private let farmingService: DemeterFarmingServiceProtocol
    private let itemFactory = PoolDetailsItemFactory()
    private let group = DispatchGroup()
    private var apy: SbApyInfo?
    private var pools: [StakedPool] = []
    
    init(
        wireframe: PoolDetailsWireframeProtocol?,
        poolInfo: PoolInfo,
        fiatService: FiatServiceProtocol,
        poolsService: PoolsServiceInputProtocol?,
        assetManager: AssetManagerProtocol,
        detailsFactory: DetailViewModelFactoryProtocol,
        providerFactory: BalanceProviderFactory,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol?,
        farmingService: DemeterFarmingServiceProtocol
    ) {
        self.poolInfo = poolInfo
        self.apyService = APYService.shared
        self.fiatService = fiatService
        self.wireframe = wireframe
        self.poolsService = poolsService
        self.assetManager = assetManager
        self.detailsFactory = detailsFactory
        self.providerFactory = providerFactory
        self.operationFactory = operationFactory
        self.assetsProvider = assetsProvider
        self.farmingService = farmingService
        self.poolsService?.appendDelegate(delegate: self)
        self.poolsService?.subscribePoolsReserves([poolInfo])
    }
    
    func dissmissIfNeeded() {
        if isDeletedPool {
            dismiss?()
        }
    }
}

extension PoolDetailsViewModel: PoolDetailsViewModelProtocol {
    func viewDidLoad() {
        updateContent()
    }
    
    func apyInfoButtonTapped() {
        wireframe?.present(
            message: R.string.localizable.polkaswapSbApyInfo(),
            title: R.string.localizable.poolApyTitle(),
            closeAction: R.string.localizable.commonOk(),
            from: view
        )
    }
    
    func dismissed() {
        dismissHandler?()
    }
    
    func infoButtonTapped(with type: Liquidity.TransactionLiquidityType) {
        wireframe?.showLiquidity(on: view?.controller,
                                 poolInfo: poolInfo,
                                 type: type,
                                 assetManager: assetManager,
                                 poolsService: poolsService,
                                 fiatService: fiatService,
                                 providerFactory: providerFactory,
                                 operationFactory: operationFactory,
                                 assetsProvider: assetsProvider,
                                 completionHandler: dissmissIfNeeded)
    }
}

extension PoolDetailsViewModel: PoolsServiceOutput {
    func loaded(pools: [PoolInfo]) {
        guard let pool = pools.first(where: { $0.baseAssetId == poolInfo.baseAssetId && $0.targetAssetId == poolInfo.targetAssetId }) else {
            isDeletedPool = true
            dismiss?()
            return
        }
        
        poolInfo = pool
    }
}

extension PoolDetailsViewModel {
    func updateContent() {
        group.enter()
        apyService.getApy(for: poolInfo.baseAssetId, targetAssetId: poolInfo.targetAssetId) { [weak self] apy in
            self?.apy = apy
            self?.group.leave()
        }
        
        group.enter()
        farmingService.getFarmedPools(baseAssetId: poolInfo.baseAssetId, targetAssetId: poolInfo.targetAssetId) { [weak self] pools in
            self?.pools = pools
            self?.group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            var items: [SoramitsuTableViewItemProtocol] = []
            
            let poolDetailsItem = self.itemFactory.createAccountItem(with: self.assetManager,
                                                                     poolInfo: self.poolInfo,
                                                                     apy: self.apy,
                                                                     detailsFactory: self.detailsFactory,
                                                                     viewModel: self,
                                                                     pools: self.pools)
            items.append(poolDetailsItem)
            items.append(SoramitsuTableViewSpacerItem(space: 8, color: .custom(uiColor: .clear)))
            
            let stakedItems = self.pools.map {
                self.itemFactory.stakedItem(with: self.assetManager, poolInfo: self.poolInfo, stakedPool: $0)
            }
            
            stakedItems.enumerated().forEach { (index, item) in
                items.append(item)
                if index != stakedItems.count - 1 {
                    items.append(SoramitsuTableViewSpacerItem(space: 8, color: .custom(uiColor: .clear)))
                }
            }

            self.setupItems?(items)
        }
    }
}
