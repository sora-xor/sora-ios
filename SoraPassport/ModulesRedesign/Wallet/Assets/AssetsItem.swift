import Foundation
import SoraUIKit
import CommonWallet
import RobinHood

final class AssetsItem: NSObject {

    var title: String
    var moneyText: String = ""
    
    var assetViewModels: [AssetViewModel] = []
    var isExpand: Bool
    let assetViewModelsFactory: AssetViewModelFactoryProtocol
    weak var fiatService: FiatServiceProtocol?
    var updateHandler: (() -> Void)?
    var expandButtonHandler: (() -> Void)?
    var arrowButtonHandler: (() -> Void)?
    var assetHandler: ((String) -> Void)?
    let debouncer = Debouncer(interval: 0.5)
    let assetProvider: AssetProviderProtocol
    let assetManager: AssetManagerProtocol

    init(title: String,
         isExpand: Bool = true,
         assetProvider: AssetProviderProtocol,
         assetManager: AssetManagerProtocol,
         fiatService: FiatServiceProtocol?,
         assetViewModelsFactory: AssetViewModelFactoryProtocol) {
        self.title = title
        self.isExpand = isExpand
        self.fiatService = fiatService
        self.assetViewModelsFactory = assetViewModelsFactory
        self.assetProvider = assetProvider
        self.assetManager = assetManager
        super.init()
        self.assetProvider.add(observer: self)
    }
    
    public func updateContent() {
        self.fiatService?.getFiat { fiatData in
            let assetIds = self.assetManager.getAssetList()?.filter { $0.visible }.map { $0.assetId } ?? []
            let items = self.assetProvider.getBalances(with: assetIds)
            let fiatDecimal = items.reduce(Decimal(0), { partialResult, balanceData in
                if let priceUsd = fiatData.first(where: { $0.id == balanceData.identifier })?.priceUsd?.decimalValue {
                    return partialResult + balanceData.balance.decimalValue * priceUsd
                }
                return partialResult
            })

            self.moneyText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")

            self.assetViewModels = items.compactMap { item in
                self.assetViewModelsFactory.createAssetViewModel(with: item, fiatData: fiatData, mode: .view)
            }
            self.updateHandler?()
        }
        
    }
}

extension AssetsItem: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        updateContent()
    }
}

extension AssetsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { AssetsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
