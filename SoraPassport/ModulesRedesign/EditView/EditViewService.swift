import CommonWallet
import FearlessUtils
import RobinHood
import XNetworking

protocol EditViewServiceProtocol: AnyObject, PoolsServiceOutput {
    var viewModels: [EnabledViewModel] { get set }
    func loadModels(completion: ((Bool) -> Void)?)
}

final class EditViewService {
    
    var poolsService: PoolsServiceInputProtocol
    var viewModels: [EnabledViewModel] = []
    var completion: ((Bool) -> Void)?
    
    init(poolsService: PoolsServiceInputProtocol) {
        self.poolsService = poolsService
    }
}

extension EditViewService: EditViewServiceProtocol {
    func loadModels(completion: ((Bool) -> Void)?) {
        poolsService.loadPools(isNeedForceUpdate: false)
        self.completion = completion
    }
    
    func loaded(pools: [PoolInfo]) {
        completion?(!pools.isEmpty)
        completion = nil
    }
}
