import Foundation
import Combine
import BigInt

final class ExplorePoolViewModelService {
    var apyService: APYServiceProtocol
    let itemFactory: ExploreItemFactory
    var poolService: ExplorePoolsServiceInputProtocol
    
    @Published var viewModels: [ExplorePoolViewModel] = [ ExplorePoolViewModel(serialNumber: "1"),
                                                          ExplorePoolViewModel(serialNumber: "2"),
                                                          ExplorePoolViewModel(serialNumber: "3"),
                                                          ExplorePoolViewModel(serialNumber: "4"),
                                                          ExplorePoolViewModel(serialNumber: "5") ]
    
    init(
        itemFactory: ExploreItemFactory,
        poolService: ExplorePoolsServiceInputProtocol,
        apyService: APYServiceProtocol
    ) {
        self.poolService = poolService
        self.itemFactory = itemFactory
        self.apyService = apyService
    }
    
    func setup() {
        Task {
            let pools = (try? await poolService.getPools()) ?? []
            
            viewModels = pools.enumerated().compactMap { (index, pool) in
                return itemFactory.createPoolsItem(with: pool, serialNumber: String(index + 1))
            }
            
            viewModels = (await pools.enumerated().asyncCompactMap { (index, pool) in
                let apy = await apyService.getApy(for: pool.baseAssetId, targetAssetId: pool.targetAssetId)
                return itemFactory.createPoolsItem(with: pool, serialNumber: String(index + 1), apy: apy)
            })
        }
    }
}
