import BigInt
import CommonWallet
import Foundation
import SoraKeystore
import UIKit

final class PolkaswapPoolPresenter: PolkaswapPoolPresenterProtocol {
    let tab: PolkaswapTab = .pool
    weak var view: PolkaswapPoolViewProtocol?
    var interactor: PolkaswapPoolInteractorInputProtocol!
    var networkFacade: WalletNetworkOperationFactoryProtocol
    let polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol
    let assetManager: AssetManagerProtocol
    var assets: [AssetInfo]
    var assetList: [AssetInfo] {
        assets
    }
    let commandFactory: WalletCommandFactoryProtocol
    var wireframe: PolkaswapMainWireframeProtocol!
    var pools: [PoolDetails] = []
    weak var liquidityController: LiquidityViewController?

    init(assetManager: AssetManagerProtocol,
         networkFacade: WalletNetworkOperationFactoryProtocol,
         polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
         assets: [AssetInfo],
         commandFactory: WalletCommandFactoryProtocol
    ) {
        self.assetManager = assetManager
        self.networkFacade = networkFacade
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.assets = assets
        self.commandFactory = commandFactory
    }

    func showAddLiquidity(_ pool: PoolDetails) {
        guard let firstAsset = assetList.first { $0.identifier == pool.baseAsset },
        let secondAsset = assetList.first { $0.identifier == pool.targetAsset },
            let viewController = LiquidityFactory.createAddLiquidityViewController(assets: assets,
                                                                                   firstAsset: firstAsset,
                                                                                   secondAsset: secondAsset,
                                                                                   details: pool,
                                                                                   activePoolsList: pools,
                                                                                   networkFacade: networkFacade,
                                                                                   polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                                                   commandFactory: commandFactory,
                                                                                   amountFormatterFactory: AmountFormatterFactory())
         else { return }
        liquidityController = viewController
        let presentationCommand = commandFactory.preparePresentationCommand(for: viewController)
        presentationCommand.presentationStyle = .modal(inNavigation: true)
        try? presentationCommand.execute()
    }

    func showRemoveLiquidity(_ pool: PoolDetails) {
        guard
            let firstAsset = assetList.first { $0.identifier == pool.baseAsset },
            let secondAsset = assetList.first { $0.identifier == pool.targetAsset },
            let viewController = LiquidityFactory.createRemoveLiquidityViewController(firstAsset: firstAsset,
                                                                                      secondAsset: secondAsset,
                                                                                      details: pool,
                                                                                      activePoolsList: pools,
                                                                                      networkFacade: networkFacade,
                                                                                      polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                                                      commandFactory: commandFactory,
                                                                                      amountFormatterFactory: AmountFormatterFactory())
        else {return}
        liquidityController = viewController
        let presentationCommand = commandFactory.preparePresentationCommand(for: viewController)
        presentationCommand.presentationStyle = .modal(inNavigation: true)
        try? presentationCommand.execute()
    }

    func showCreateLiquidity() {
        guard
            let firstAsset = assetList.first { $0.identifier == WalletAssetId.xor.rawValue },
            let viewController = LiquidityFactory.createLiquidityViewController(
                assets: assets,
                firstAsset: firstAsset,
                activePoolsList: pools,
                networkFacade: networkFacade,
                polkaswapNetworkFacade: polkaswapNetworkFacade,
                commandFactory: commandFactory,
                amountFormatterFactory: AmountFormatterFactory()
            )
        else { return }
        liquidityController = viewController
        let presentationCommand = commandFactory.preparePresentationCommand(for: viewController)
        presentationCommand.presentationStyle = .modal(inNavigation: true)
        try? presentationCommand.execute()
    }
}

extension PolkaswapPoolPresenter: PolkaswapMainInteractorOutputProtocol {
    func didCheckPath(fromAssetId: String, toAssetId: String, isAvailable: Bool) {

    }

    func didLoadMarketSources(_: [String], fromAssetId: String, toAssetId: String) {

    }

    func didLoadQuote(_: SwapValues?, params: PolkaswapMainInteractorQuoteParams) {

    }

    func didLoadBalance(_: Decimal, asset: AssetInfo) {

    }

    func didLoadPools(_ pools: [PoolDetails]) {
        let assetListIds = assetList.map(\.identifier)
        let filteredPools = pools.filter({ assetListIds.contains($0.targetAsset) })
        self.pools = filteredPools
        liquidityController?.presenter.didLoadPools(filteredPools)
        view?.setPoolList(filteredPools)
        interactor.subscribePoolsReserves(filteredPools)
    }

    func didUpdatePoolSubscription() {

    }

    func didUpdateBalance() {

    }

    func didUpdateBalance(isActiveTab: Bool) {

    }

    func didCreateTransaction() {

    }
}

extension PolkaswapPoolPresenter: PolkaswapPoolInteractorOutputProtocol {
    func didUpdateAccountPools() {
        interactor.loadPools()
    }

    func didUpdateAccountPoolReserves(baseAsset: String, targetAsset: String) {
        //TODO: OPTIMIZE THIS. LOAD ONLY THE UPDATED POOL'S DETAILS.
        interactor.loadPools()
    }
}
