import Foundation
import UIKit
import CommonWallet
import RobinHood

protocol RedesignWalletCoordinatorProtocol {
    func showFullListAssets(balanceProvider: SingleValueProvider<[BalanceData]>?,
                            assetManager: AssetManagerProtocol,
                            assetViewModelFactory: AssetViewModelFactoryProtocol)
}

final class WalletCoordinator: RedesignWalletCoordinatorProtocol {
    var rootController: UIViewController

    init(rootController: UIViewController) {
        self.rootController = rootController
    }

    func showFullListAssets(balanceProvider: SingleValueProvider<[BalanceData]>?,
                            assetManager: AssetManagerProtocol,
                            assetViewModelFactory: AssetViewModelFactoryProtocol) {
        let viewModel = AssetListViewModel(balanceProvider: balanceProvider,
                                           assetViewModelFactory: assetViewModelFactory,
                                           assetManager: assetManager)

        let assetListController = AssetListViewController(viewModel: viewModel)

        let navigationController = UINavigationController(rootViewController: assetListController)
        navigationController.modalPresentationStyle = .fullScreen

        rootController.present(navigationController, animated: true)
    }
}
