import Foundation
import SoraFoundation
import CommonWallet

//swiftlint:disable function_parameter_count

final class LiquidityFactory: LiquidityFactoryProtocol {
    
    static func createLiquidityViewController(
        assets: [AssetInfo],
        firstAsset: AssetInfo,
        activePoolsList: [PoolDetails],
        networkFacade: WalletNetworkOperationFactoryProtocol,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
        commandFactory: WalletCommandFactoryProtocol,
        amountFormatterFactory: AmountFormatterFactoryProtocol?
    ) -> LiquidityViewController? {
        return createView(
            isAddingLiquidity: true,
            assets: assets,
            firstAsset: firstAsset,
            secondAsset: nil,
            details: nil,
            activePoolsList: activePoolsList,
            networkFacade: networkFacade,
            polkaswapNetworkFacade: polkaswapNetworkFacade,
            commandFactory: commandFactory,
            amountFormatterFactory: amountFormatterFactory
        )
    }

    static func createAddLiquidityViewController(
        assets: [AssetInfo],
        firstAsset: AssetInfo,
        secondAsset: AssetInfo,
        details: PoolDetails,
        activePoolsList: [PoolDetails],
        networkFacade: WalletNetworkOperationFactoryProtocol,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
        commandFactory: WalletCommandFactoryProtocol,
        amountFormatterFactory: AmountFormatterFactoryProtocol?
    ) -> LiquidityViewController? {
        return createView(
            isAddingLiquidity: true,
            assets: assets,
            firstAsset: firstAsset,
            secondAsset: secondAsset,
            details: details,
            activePoolsList: activePoolsList,
            networkFacade: networkFacade,
            polkaswapNetworkFacade: polkaswapNetworkFacade,
            commandFactory: commandFactory,
            amountFormatterFactory: amountFormatterFactory
        )
    }

    static func createRemoveLiquidityViewController(
        firstAsset: AssetInfo,
        secondAsset: AssetInfo,
        details: PoolDetails,
        activePoolsList: [PoolDetails],
        networkFacade: WalletNetworkOperationFactoryProtocol,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
        commandFactory: WalletCommandFactoryProtocol,
        amountFormatterFactory: AmountFormatterFactoryProtocol?
    ) -> LiquidityViewController? {
        return createView(
            isAddingLiquidity: false,
            assets: [],
            firstAsset: firstAsset,
            secondAsset: secondAsset,
            details: details,
            activePoolsList: activePoolsList,
            networkFacade: networkFacade,
            polkaswapNetworkFacade: polkaswapNetworkFacade,
            commandFactory: commandFactory,
            amountFormatterFactory: amountFormatterFactory
        )
    }

    private static func createView(
        isAddingLiquidity: Bool,
        assets: [AssetInfo],
        firstAsset: AssetInfo,
        secondAsset: AssetInfo?,
        details: PoolDetails?,
        activePoolsList: [PoolDetails],
        networkFacade: WalletNetworkOperationFactoryProtocol,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
        commandFactory: WalletCommandFactoryProtocol,
        amountFormatterFactory: AmountFormatterFactoryProtocol?
    ) -> LiquidityViewController? {
        let viewController = LiquidityViewController(nib: R.nib.liquidityViewController)
        viewController.modalPresentationStyle = .pageSheet
        viewController.navigationItem.largeTitleDisplayMode = .never
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        var presenter: LiquidityPresenterProtocol
        if isAddingLiquidity {
            presenter = LiquidityAddPresenter(
                assets: assets,
                assetManager: assetManager,
                pool: details,
                commandFactory: commandFactory,
                firstAsset: firstAsset,
                secondAsset: secondAsset,
                activePoolsList: activePoolsList
            )
        } else {
            guard let details = details,
                  let secondAsset = secondAsset else {
                return nil
            }
            presenter = LiquidityRemovePresenter(
                assets: assets,
                assetManager: assetManager,
                pool: details,
                commandFactory: commandFactory,
                firstAsset: firstAsset,
                secondAsset: secondAsset,
                activePoolsList: activePoolsList
            )
        }

        presenter.view = viewController
        presenter.amountFormatterFactory = amountFormatterFactory

        let interactor = LiquidityInteractor(operationManager: OperationManagerFacade.sharedManager,
                                             networkFacade: networkFacade,
                                             polkaswapNetworkFacade: polkaswapNetworkFacade,
                                             feeProvider: FeeProvider())
        interactor.presenter = presenter
        presenter.interactor = interactor
        presenter.wireframe = LiquidityWireframe()
        viewController.presenter = presenter
        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }
}
