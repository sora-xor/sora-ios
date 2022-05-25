import Foundation
import SoraFoundation
import CommonWallet

final class LiquidityFactory: LiquidityFactoryProtocol {
    static func createAddLiquidityViewController(firstAsset: WalletAsset,
                                                 secondAsset: WalletAsset,
                                                 details: PoolDetails,
                                                 networkFacade: WalletNetworkOperationFactoryProtocol,
                                                 commandFactory: WalletCommandFactoryProtocol,
                                                 amountFormatterFactory: AmountFormatterFactoryProtocol?) -> LiquidityViewController? {
        return createView(mode: .liquidityAdd, firstAsset: firstAsset, secondAsset: secondAsset, details: details, networkFacade: networkFacade, commandFactory: commandFactory, amountFormatterFactory: amountFormatterFactory)

    }

    
    static func createRemoveLiquidityViewController(
        firstAsset: WalletAsset,
        secondAsset: WalletAsset,
        details: PoolDetails,
        networkFacade: WalletNetworkOperationFactoryProtocol,
        commandFactory: WalletCommandFactoryProtocol,
        amountFormatterFactory: AmountFormatterFactoryProtocol?
    ) -> LiquidityViewController? {
        return createView(mode: .liquidityRemoval, firstAsset: firstAsset, secondAsset: secondAsset, details: details, networkFacade: networkFacade, commandFactory: commandFactory, amountFormatterFactory: amountFormatterFactory)
    }

    private static func createView(mode: TransactionType,
                           firstAsset: WalletAsset,
                           secondAsset: WalletAsset,
                           details: PoolDetails,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           commandFactory: WalletCommandFactoryProtocol,
                           amountFormatterFactory: AmountFormatterFactoryProtocol?) -> LiquidityViewController? {
        let viewController = LiquidityViewController(nib: R.nib.liquidityViewController)
        viewController.modalPresentationStyle = .pageSheet
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.amountFormatterFactory = amountFormatterFactory
        let presenter = LiquidityPresenter(assetManager: AssetManager.shared, mode: mode, pool: details, commandFactory: commandFactory)
        let interactor = LiquidityInteractor(operationManager: OperationManagerFacade.sharedManager, networkFacade: networkFacade)
        let wireframe = LiquidityWireframe()
        viewController.presenter = presenter
        viewController.localizationManager = LocalizationManager.shared
        presenter.interactor = interactor
        interactor.presenter = presenter
        presenter.view = viewController
        presenter.firstAsset = firstAsset
        presenter.secondAsset = secondAsset
        presenter.amountFormatterFactory = amountFormatterFactory
        presenter.wireframe = wireframe
        return viewController
    }
}
