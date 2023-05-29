import UIKit
import SoraUIKit
import CommonWallet
import RobinHood

protocol DiscoverViewModelProtocol: SoramitsuTableViewPaginationHandlerProtocol {
    func fetchItems(completion: ([SoramitsuTableViewItemProtocol]) -> Void)
}

final class DiscoverViewModel {
    var setupItem: (([SoramitsuTableViewItemProtocol]) -> Void)?

    var wireframe: DiscoveryWireframe = DiscoveryWireframe()
    var items: [SoramitsuTableViewItemProtocol] = []
    var view: ControllerBackedProtocol?
    
    var assetManager: AssetManagerProtocol
    var poolsService: PoolsServiceInputProtocol?
    var fiatService: FiatServiceProtocol?
    var operationFactory: WalletNetworkOperationFactoryProtocol
    var assetsProvider: AssetProviderProtocol
    
    
    init(assetManager: AssetManagerProtocol,
         poolsService: PoolsServiceInputProtocol?,
         fiatService: FiatServiceProtocol?,
         operationFactory: WalletNetworkOperationFactoryProtocol,
         assetsProvider: AssetProviderProtocol) {
        self.assetManager = assetManager
        self.poolsService = poolsService
        self.fiatService = fiatService
        self.operationFactory = operationFactory
        self.assetsProvider = assetsProvider
    }
}

extension DiscoverViewModel: DiscoverViewModelProtocol {
    func fetchItems(completion: ([SoramitsuTableViewItemProtocol]) -> Void) {
        let discoverItem = DiscoverItem()
        discoverItem.handler = { [weak self] in
            guard let self = self, let view = self.view?.controller else { return }
            
            self.wireframe.showLiquidity(on: view,
                                         assetManager: self.assetManager,
                                         poolsService: self.poolsService,
                                         fiatService: self.fiatService,
                                         operationFactory: self.operationFactory,
                                         assetsProvider: self.assetsProvider)
        }
        
        completion([ discoverItem ])
    }
}
