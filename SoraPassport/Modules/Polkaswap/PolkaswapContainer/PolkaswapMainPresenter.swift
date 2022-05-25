import BigInt
import CommonWallet
import Foundation
import SoraKeystore
import UIKit

final class PolkaswapMainPresenter: PolkaswapMainPresenterProtocol {

    weak var view: PolkaswapMainViewProtocol?
    var wireframe: PolkaswapMainWireframeProtocol!
    let presenters: [PolkaswapMainInteractorOutputProtocol]

    init(
        swapPresenter: PolkaswapMainInteractorOutputProtocol,
        poolPresenter: PolkaswapMainInteractorOutputProtocol
    ) {
        presenters = [swapPresenter, poolPresenter]
    }
}

extension PolkaswapMainPresenter: PolkaswapMainInteractorOutputProtocol {
    func didCheckPath(fromAssetId: String, toAssetId: String, isAvailable: Bool) {
        presenters.forEach {$0.didCheckPath(fromAssetId: fromAssetId, toAssetId: toAssetId, isAvailable: isAvailable) }
    }

    func didLoadMarketSources(_ marketSources: [String], fromAssetId: String, toAssetId: String) {
        presenters.forEach {$0.didLoadMarketSources(marketSources, fromAssetId: fromAssetId, toAssetId: toAssetId) }
    }

    func didLoadQuote(_ values: SwapValues?, params: PolkaswapMainInteractorQuoteParams) {
        presenters.forEach {$0.didLoadQuote(values, params: params) }
    }

    func didLoadBalance(_ balance: Decimal, asset: WalletAsset) {
        presenters.forEach {$0.didLoadBalance(balance, asset: asset) }
    }

    func didLoadPools(_ pools: [PoolDetails]) {
        presenters.forEach {$0.didLoadPools(pools) }
    }

    func didUpdatePoolSubscription() {
        presenters.forEach {$0.didUpdatePoolSubscription() }
    }

    func didUpdateBalance() {
        presenters.forEach {$0.didUpdateBalance() }
    }

    func didCreateTransaction() {
        presenters.forEach {$0.didCreateTransaction() }
    }
}
