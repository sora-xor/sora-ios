import Foundation
import SoraSwiftUI
import CommonWallet
import RobinHood

final class AssetsItem: NSObject {

    let title: String
    let moneyText: String
    
    var assetViewModels: [AssetViewModel] = []
    var isExpand: Bool
    let balanceProvider: (SingleValueProvider<[BalanceData]>)?
    let assetViewModelsFactory: AssetViewModelFactoryProtocol
    var updateHandler: (() -> Void)?
    var expandButtonHandler: (() -> Void)?
    var arrowButtonHandler: (() -> Void)?

    init(title: String,
         moneyText: String = "",
         isExpand: Bool = true,
         balanceProvider: (SingleValueProvider<[BalanceData]>)?,
         assetViewModelsFactory: AssetViewModelFactoryProtocol) {
        self.title = title
        self.moneyText = moneyText
        self.isExpand = isExpand
        self.balanceProvider = balanceProvider
        self.assetViewModelsFactory = assetViewModelsFactory
        super.init()
        setupBalanceDataProvider()
    }

    private func setupBalanceDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<[BalanceData]>]) -> Void in
            guard let self = self, let change = changes.first else { return }
            switch change {
            case .insert(let items), .update(let items):
                self.assetViewModels = items.compactMap { item in
                    self.assetViewModelsFactory.createAssetViewModel(with: item, mode: .view)
                }
                self.updateHandler?()
            default: break
            }
        }

        let failBlock: (Error) -> Void = { (error: Error) in
            //TODO: Add error handler
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        balanceProvider?.addObserver(self,
                                    deliverOn: .main,
                                    executing: changesBlock,
                                    failing: failBlock,
                                    options: options)
    }
}

extension AssetsItem: EventVisitorProtocol {
    func processBalanceChanged(event: WalletBalanceChanged) {
        balanceProvider?.refresh()
    }
}

extension AssetsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { AssetsCell.self }

    var backgroundColor: SoramitsuColor { .bgPage }

    var clipsToBounds: Bool { false }
}
