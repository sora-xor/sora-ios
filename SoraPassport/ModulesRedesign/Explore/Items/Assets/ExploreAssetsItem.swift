import Foundation
import SoraUIKit
import CommonWallet
import RobinHood
import BigInt

struct ExploreAssetLiquidity {
    let tokenId: String
    let marketCap: Decimal
}

struct ExploreAssetViewModel: Hashable {
    var assetId: String?
    var symbol: String?
    var title: String?
    var price: String?
    var serialNumber: String
    var marketCap: String?
    var icon: UIImage?
}


final class ExploreAssetsItem: ItemProtocol {

    var title: String
    var subTitle: String
    var assetHandler: ((String) -> Void)?
    var expandHandler: (() -> Void)?
    weak var viewModelService: ExploreAssetViewModelService?

    init(title: String,
         subTitle: String,
         viewModelService: ExploreAssetViewModelService?) {
        self.title = title
        self.subTitle = subTitle
        self.viewModelService = viewModelService
    }
}

extension ExploreAssetsItem: Hashable {
    static func == (lhs: ExploreAssetsItem, rhs: ExploreAssetsItem) -> Bool {
        lhs.viewModelService?.viewModels == rhs.viewModelService?.viewModels
    }
    
    public func hash(into hasher: inout Hasher) {
        return hasher.combine(viewModelService?.viewModels)
    }
}
