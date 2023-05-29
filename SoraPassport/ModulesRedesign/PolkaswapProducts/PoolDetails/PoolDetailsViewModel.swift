import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import SoraFoundation

protocol PoolDetailsViewModelProtocol: AnyObject {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var dismiss: (() -> Void)? { get set }
    func viewDidLoad()
    func apyInfoButtonTapped()
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
    
    init(
        wireframe: PoolDetailsWireframeProtocol?,
        poolInfo: PoolInfo,
        fiatService: FiatServiceProtocol,
        poolsService: PoolsServiceInputProtocol?,
        assetManager: AssetManagerProtocol,
        detailsFactory: DetailViewModelFactoryProtocol,
        providerFactory: BalanceProviderFactory,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol?
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
        apyService.getApy(for: poolInfo.baseAssetId, targetAssetId: poolInfo.targetAssetId) { [weak self] apy in
            guard let self = self else { return }
            
            let baseAsset = self.assetManager.assetInfo(for: self.poolInfo.baseAssetId)
            let targetAsset = self.assetManager.assetInfo(for: self.poolInfo.targetAssetId)
            let rewardAsset = self.assetManager.assetInfo(for: WalletAssetId.pswap.rawValue)
            
            let baseAssetSymbol = baseAsset?.symbol.uppercased() ?? ""
            let targetAssetSymbol = targetAsset?.symbol.uppercased() ?? ""
            
            var firstAssetImage: WalletImageViewModelProtocol?
            if let iconString = baseAsset?.icon {
                firstAssetImage = WalletSvgImageViewModel(svgString: iconString)
            }
            
            var secondAssetImage: WalletImageViewModelProtocol?
            if let iconString = targetAsset?.icon {
                secondAssetImage = WalletSvgImageViewModel(svgString: iconString)
            }
            
            var rewardAssetImage: WalletImageViewModelProtocol?
            if let iconString = rewardAsset?.icon {
                rewardAssetImage = WalletSvgImageViewModel(svgString: iconString)
            }
            
            let poolText = R.string.localizable.polkaswapPoolTitle(preferredLanguages: .currentLocale)
            
            let title = "\(baseAssetSymbol)-\(targetAssetSymbol) \(poolText)"
            
            let detailsViewModels = self.detailsFactory.createPoolDetailViewModels(with: self.poolInfo, apy: apy, viewModel: self)
            
            let detailsItem = PoolDetailsItem(title: title,
                                              firstAssetImage: firstAssetImage,
                                              secondAssetImage: secondAssetImage,
                                              rewardAssetImage: rewardAssetImage,
                                              detailsViewModel: detailsViewModels)
            detailsItem.handler = { [weak self] type in
                guard let self = self else { return }
                self.wireframe?.showLiquidity(on: self.view?.controller,
                                              poolInfo: self.poolInfo,
                                              type: type,
                                              assetManager: self.assetManager,
                                              poolsService: self.poolsService,
                                              fiatService: self.fiatService,
                                              providerFactory: self.providerFactory,
                                              operationFactory: self.operationFactory,
                                              assetsProvider: self.assetsProvider,
                                              completionHandler: self.dissmissIfNeeded)
            }
            self.setupItems?([ detailsItem ])
        }
    }
}
