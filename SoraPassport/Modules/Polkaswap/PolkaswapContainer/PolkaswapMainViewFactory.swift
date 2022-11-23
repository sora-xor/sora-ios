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

        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        let assets = assetManager.getAssetList() ?? []
        let swapFactory = PolkaswapSwapFactory(assetManager: assetManager, amountFormatterFactory: AmountFormatterFactory())
        let swapView = PolkaswapSwapView(nibName: R.nib.swapView.name, bundle: R.nib.swapView.bundle, swapFactory: swapFactory)
        swapView.localizationManager = LocalizationManager.shared
        let swapPresenter = SwapPresenter(assets: assets,
                                          assetManager: assetManager,
                                          disclaimerViewFactory: DisclaimerViewFactory(),
                                          settingsManager: SettingsManager.shared,
                                          networkFacade: walletContext.networkOperationFactory,
                                          polkaswapNetworkFacade: polkaswapContext,
                                          commandFactory: walletContext)
        swapView.presenter = swapPresenter
        swapPresenter.view = swapView
        swapPresenter.interactor = interactor

        let poolView = PolkaswapPoolFactory.createView(networkFacade: walletContext.networkOperationFactory,
                                                       polkaswapNetworkFacade: polkaswapContext,
                                                       assets: assets,
                                                       commandFactory: walletContext)
        poolView.localizationManager = LocalizationManager.shared

        let presenter = PolkaswapMainPresenter(swapPresenter: swapPresenter, poolPresenter: poolView.presenter!)

        let wireframe = PolkaswapMainWireframe()

        containerView.swapView = swapView
        containerView.poolView = poolView
        containerView.presenter = presenter
        presenter.view = containerView
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        return containerView
    }
}
