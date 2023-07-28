import Foundation
import SoraUIKit
import CommonWallet
import RobinHood

struct ExplorePoolViewModel: Hashable {
    var poolId: String?
    var title: String?
    var tvl: String?
    var serialNumber: String
    var apy: String?
    var baseAssetId: String?
    var targetAssetId: String?
    var baseAssetIcon: UIImage?
    var targetAssetIcon: UIImage?
}

final class ExplorePoolsItem: ItemProtocol {

    var title: String
    var subTitle: String
    
    @Published var poolViewModels: [ExplorePoolViewModel] = [ ExplorePoolViewModel(serialNumber: String(1)),
                                                              ExplorePoolViewModel(serialNumber: String(2)),
                                                              ExplorePoolViewModel(serialNumber: String(3)),
                                                              ExplorePoolViewModel(serialNumber: String(4)),
                                                              ExplorePoolViewModel(serialNumber: String(5)) ]
    var poolHandler: ((ExplorePoolViewModel) -> Void)?
    var expandHandler: (() -> Void)?
    weak var viewModelService: ExplorePoolViewModelService?

    init(title: String,
         subTitle: String,
         viewModelService: ExplorePoolViewModelService) {
        self.title = title
        self.subTitle = subTitle
        self.viewModelService = viewModelService
    }
}

extension ExplorePoolsItem: Hashable {
    static func == (lhs: ExplorePoolsItem, rhs: ExplorePoolsItem) -> Bool {
        lhs.poolViewModels == rhs.poolViewModels
    }
    
    public func hash(into hasher: inout Hasher) {
        return hasher.combine(poolViewModels)
    }
}
