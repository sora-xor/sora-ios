import Foundation
import CommonWallet

protocol PolkaswapMainViewProtocol: ControllerBackedProtocol {
}

protocol PolkaswapMainPresenterProtocol: AnyObject {
}

protocol PolkaswapMainInteractorInputProtocol: AnyObject {
    func checkIsPathAvailable(fromAssetId: String, toAssetId: String)
    func loadMarketSources(fromAssetId: String, toAssetId: String)
    func quote(params: PolkaswapMainInteractorQuoteParams)
    func loadBalance(asset: WalletAsset)
    func loadPools()
    func unsubscribePoolXYK()
    func unsubscribePoolTBC()
    func subscribePoolXYK(assetId1: String, assetId2: String)
    func subscribePoolTBC(assetId: String)
}

protocol PolkaswapMainInteractorOutputProtocol: AnyObject {
    func didCheckPath(fromAssetId: String, toAssetId: String, isAvailable: Bool)
    func didLoadMarketSources(_: [String], fromAssetId: String, toAssetId: String)
    func didLoadQuote(_: SwapValues?, params: PolkaswapMainInteractorQuoteParams)
    func didLoadBalance(_: Decimal, asset: WalletAsset)
    func didLoadPools(_ pools: [PoolDetails])
    func didUpdatePoolSubscription()
    func didUpdateBalance()
    func didCreateTransaction()
}

protocol PolkaswapMainWireframeProtocol: AnyObject {
}

protocol PolkaswapMainViewFactoryProtocol: AnyObject {
    // we use walletContext to get shared commands and network functionality from there
    static func createView(walletContext: CommonWalletContextProtocol, polkaswapContext: PolkaswapNetworkOperationFactoryProtocol) -> PolkaswapMainViewProtocol?
}
