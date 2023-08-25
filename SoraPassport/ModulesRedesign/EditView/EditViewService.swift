import CommonWallet
import FearlessUtils
import RobinHood
import XNetworking

protocol EditViewServiceProtocol: AnyObject {
    var viewModels: [EnabledViewModel] { get }
    func loadModels()
}

final class EditViewService {
    
    var poolsService: PoolsServiceInputProtocol
    var viewModels: [EnabledViewModel] = []
    
    init(poolsService: PoolsServiceInputProtocol) {
        self.poolsService = poolsService
    }
}

extension EditViewService: EditViewServiceProtocol {
    func loadModels() {
        poolsService.loadPools(isNeedForceUpdate: false)
        
        var models = Cards.allCases.map { card in
            EnabledViewModel(id: card.id,
                             title: card.title,
                             state: card.defaultState)
        }
        
        if !poolsService.isPoolsExists() {
            models.removeAll(where: { $0.id == Cards.pooledAssets.id })
            ApplicationConfig.shared.enabledCardIdentifiers = models.filter { $0.state != .disabled }.map { $0.id }
        }
        
        viewModels = models
    }
}
