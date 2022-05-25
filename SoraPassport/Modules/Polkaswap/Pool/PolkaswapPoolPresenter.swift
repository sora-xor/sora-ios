import BigInt
import CommonWallet
import Foundation
import SoraKeystore
import UIKit

final class PolkaswapPoolPresenter {

    weak var view: PolkaswapPoolViewProtocol?
    var networkFacade: WalletNetworkOperationFactoryProtocol
    let assetManager: AssetManagerProtocol
    let assetList: [WalletAsset]
    let commandFactory: WalletCommandFactoryProtocol
    var wireframe: PolkaswapMainWireframeProtocol!

    init(assetManager: AssetManagerProtocol,
         networkFacade: WalletNetworkOperationFactoryProtocol,
         assets: [WalletAsset],
         commandFactory: WalletCommandFactoryProtocol
    ) {
        self.assetManager = assetManager
        self.networkFacade = networkFacade
        self.assetList = assets
        self.commandFactory = commandFactory
    }

    func showAddLiquidity(_ pool: PoolDetails) {
        guard let firstAsset = assetList.first{ $0.identifier == WalletAssetId.xor.rawValue },
        let secondAsset = assetList.first{ $0.identifier == pool.targetAsset },
            let viewController = LiquidityFactory.createAddLiquidityViewController(firstAsset: firstAsset, secondAsset: secondAsset, details: pool, networkFacade: networkFacade, commandFactory: commandFactory, amountFormatterFactory: AmountFormatterFactory())
         else { return }
        let presentationCommand = commandFactory.preparePresentationCommand(for: viewController)
        presentationCommand.presentationStyle = .modal(inNavigation: true)
        try? presentationCommand.execute()
    }

    func showRemoveLiquidity(_ pool: PoolDetails) {
        guard let firstAsset = assetList.first{ $0.identifier == WalletAssetId.xor.rawValue },
        let secondAsset = assetList.first{ $0.identifier == pool.targetAsset },
            let viewController = LiquidityFactory.createRemoveLiquidityViewController(firstAsset: firstAsset, secondAsset: secondAsset, details: pool, networkFacade: networkFacade, commandFactory: commandFactory, amountFormatterFactory: AmountFormatterFactory())
        else {return}

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

    func didLoadBalance(_: Decimal, asset: WalletAsset) {

    }

    func didLoadPools(_ pools: [PoolDetails]) {
        view?.setPoolList(pools)
    }

    func didUpdatePoolSubscription() {

    }

    func didUpdateBalance() {

    }

    func didCreateTransaction() {
        
    }
}
