import Foundation
import SoraFoundation

protocol ActivityViewFactoryProtocol: AnyObject {
    static func createView(assetManager: AssetManagerProtocol) -> ActivityViewController?
}

final class ActivityViewFactory: ActivityViewFactoryProtocol {
    static func createView(assetManager: AssetManagerProtocol) -> ActivityViewController? {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let aseetList = assetManager.getAssetList() else { return nil }

        let localizationManager = LocalizationManager.shared
        let historyService = HistoryService(operationManager: OperationManagerFacade.sharedManager,
                                            address: selectedAccount.address,
                                            assets: aseetList)

        let viewModelFactory = ActivityViewModelFactory(walletAssets: aseetList, assetManager: assetManager)
        let viewModel = ActivityViewModel(historyService: historyService,
                                          viewModelFactory: viewModelFactory,
                                          wireframe: ActivityWireframe(),
                                          assetManager: assetManager,
                                          eventCenter: EventCenter.shared)
        viewModel.localizationManager = localizationManager
        viewModel.title = R.string.localizable.activity(preferredLanguages: .currentLocale)

        localizationManager.addObserver(with: viewModel) { [weak viewModel] (_, _) in
            viewModel?.title = R.string.localizable.activity(preferredLanguages: .currentLocale)
        }

        let view = ActivityViewController(viewModel: viewModel)
        view.localizationManager = localizationManager
        view.backgroundColor = .bgPage
        viewModel.view = view
        
        return view
    }
}



