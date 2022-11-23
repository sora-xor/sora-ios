/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import CommonWallet
import SoraFoundation

protocol PolkaswapPoolFactoryProtocol: AnyObject {
    static func createView(networkFacade: WalletNetworkOperationFactoryProtocol, polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol, assets: [AssetInfo], commandFactory: WalletCommandFactoryProtocol) -> PolkaswapPoolViewProtocol
}

protocol PolkaswapPoolViewProtocol: ControllerBackedProtocol, Localizable {
    var presenter: PolkaswapPoolPresenterProtocol? {get}
    func setPoolList(_ pools: [PoolDetails])
}

protocol PolkaswapPoolInteractorOutputProtocol: AnyObject {
    func didLoadPools(_ pools: [PoolDetails])
    func didUpdateAccountPools()
    func didUpdateAccountPoolReserves(baseAsset: String, targetAsset: String)
}

protocol PolkaswapPoolInteractorInputProtocol: AnyObject {
    func loadPools()
    func subscribePoolsReserves(_: [PoolDetails])
}

protocol PolkaswapPoolPresenterProtocol: PolkaswapMainPresenterOutputProtocol, PolkaswapPoolInteractorOutputProtocol {
    func showAddLiquidity(_ pool: PoolDetails)
    func showRemoveLiquidity(_ pool: PoolDetails)
    func showCreateLiquidity()
}
