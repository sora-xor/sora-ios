import Foundation
import SoraUIKit
import CommonWallet
import RobinHood

enum PoolItemState {
    case loading
    case empty
    case viewModel
}

final class PoolsItem: NSObject {

    var title: String
    var moneyText: String = ""
    
    var poolViewModels: [PoolViewModel] = []
    var isExpand: Bool
    let poolsService: PoolsServiceInputProtocol?
    let poolViewModelsFactory: PoolViewModelFactoryProtocol
    weak var fiatService: FiatServiceProtocol?
    var updateHandler: (() -> Void)?
    var expandButtonHandler: (() -> Void)?
    var arrowButtonHandler: (() -> Void)?
    var poolHandler: ((String) -> Void)?
    var state: PoolItemState = .loading

    init(title: String,
         isExpand: Bool = true,
         poolsService: PoolsServiceInputProtocol?,
         fiatService: FiatServiceProtocol?,
         poolViewModelsFactory: PoolViewModelFactoryProtocol) {
        self.title = title
        self.isExpand = isExpand
        self.fiatService = fiatService
        self.poolsService = poolsService
        self.poolViewModelsFactory = poolViewModelsFactory
    }
}

extension PoolsItem: PoolsServiceOutput {
    func loaded(pools: [PoolInfo]) {
        self.fiatService?.getFiat { fiatData in
            let fiatDecimal = pools.filter { $0.isFavorite }.reduce(Decimal(0), { partialResult, pool in
                if let baseAssetPriceUsd = fiatData.first(where: { $0.id == pool.baseAssetId })?.priceUsd?.decimalValue,
                   let targetAssetPriceUsd = fiatData.first(where: { $0.id == pool.targetAssetId })?.priceUsd?.decimalValue,
                   let baseAssetPooledByAccount = pool.baseAssetPooledByAccount,
                   let targetAssetPooledByAccount = pool.targetAssetPooledByAccount {
                    
                    let baseAssetFiatAmount = baseAssetPooledByAccount * baseAssetPriceUsd
                    let targetAssetFiatAmount = targetAssetPooledByAccount * targetAssetPriceUsd
                    return partialResult + baseAssetFiatAmount + targetAssetFiatAmount
                }
                return partialResult
            })

            self.moneyText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
            
            
            self.poolViewModels = pools.filter { $0.isFavorite }.compactMap { item in
                self.poolViewModelsFactory.createPoolViewModel(with: item, fiatData: fiatData, mode: .view)
            }
            if self.poolViewModels.isEmpty {
                self.state = .empty
            } else {
                self.state = .viewModel
            }
            
            self.updateHandler?()
        }
    }
}

extension PoolsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PoolsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
