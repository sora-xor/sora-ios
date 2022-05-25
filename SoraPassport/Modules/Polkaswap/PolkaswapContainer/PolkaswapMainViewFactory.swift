import Foundation
import SoraFoundation
import CommonWallet
import SoraKeystore

final class PolkaswapMainViewFactory: PolkaswapMainViewFactoryProtocol {
    static func createView(walletContext: CommonWalletContextProtocol,
                           polkaswapContext: PolkaswapNetworkOperationFactoryProtocol) -> PolkaswapMainViewProtocol? {
        let containerView = PolkaswapMainViewController(nib: R.nib.polkaswapMainViewController)

        containerView.localizationManager = LocalizationManager.shared

        let interactor = PolkaswapMainInteractor(operationManager: OperationManagerFacade.sharedManager, eventCenter: EventCenter.shared)
        interactor.networkFacade = walletContext.networkOperationFactory
        interactor.polkaswapNetworkFacade = polkaswapContext

        let primitiveFactory = WalletPrimitiveFactory(keystore: Keychain(), settings: SettingsManager.shared)
        let accountSettings = try? primitiveFactory.createAccountSettings()
        let assets = accountSettings?.assets ?? []

        let swapView = PolkaswapSwapView(nib: R.nib.swapView)
        swapView.localizationManager = LocalizationManager.shared
        let swapPresenter = SwapPresenter(assets: assets,
                                          assetManager: AssetManager.shared,
                                                   disclaimerViewFactory: DisclaimerViewFactory(),
                                                   settingsManager: SettingsManager.shared,
                                                   networkFacade: walletContext.networkOperationFactory,
                                                   polkaswapNetworkFacade: polkaswapContext,
                                                   commandFactory: walletContext)
        swapView.presenter = swapPresenter
        swapPresenter.view = swapView
        swapPresenter.interactor = interactor

        let poolPresenter = PolkaswapPoolPresenter(assetManager: AssetManager.shared, networkFacade: walletContext.networkOperationFactory, assets: assets, commandFactory: walletContext)
        let poolView = PolkaswapPoolViewController()
        poolView.localizationManager = LocalizationManager.shared
        poolPresenter.view = poolView
        poolView.presenter = poolPresenter

        let presenter = PolkaswapMainPresenter(swapPresenter: swapPresenter, poolPresenter: poolPresenter)

        let wireframe = PolkaswapMainWireframe()

        containerView.swapView = swapView
        containerView.poolView = poolView
        containerView.presenter = presenter
        presenter.view = containerView
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return containerView
    }
}
