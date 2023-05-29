import Foundation
import CommonWallet

protocol PolkaswapMainInteractorInputProtocol: AnyObject {
    func networkFeeValue(completion: @escaping (Decimal) -> Void)
    func checkIsPathAvailable(fromAssetId: String, toAssetId: String)
    func loadMarketSources(fromAssetId: String, toAssetId: String)
    func quote(params: PolkaswapMainInteractorQuoteParams)
    func loadBalance(asset: AssetInfo)
    func unsubscribePoolXYK()
    func unsubscribePoolTBC()
    func subscribePoolXYK(assetId1: String, assetId2: String)
    func subscribePoolTBC(assetId: String)
    func setup()
    func stop()
}

protocol PolkaswapMainInteractorOutputProtocol: AnyObject {
    func didCheckPath(fromAssetId: String, toAssetId: String, isAvailable: Bool)
    func didLoadMarketSources(_: [String], fromAssetId: String, toAssetId: String)
    func didLoadQuote(_: SwapValues?, dexId: UInt32, params: PolkaswapMainInteractorQuoteParams)
    func didLoadBalance(_: Decimal, asset: AssetInfo)
    func didUpdatePoolSubscription()
    func didUpdateBalance()
    func didCreateTransaction()
}

extension PolkaswapMainInteractorOutputProtocol {
    func didCheckPath(fromAssetId: String, toAssetId: String, isAvailable: Bool) {}
    func didLoadMarketSources(_ serverMarketSources: [String], fromAssetId: String, toAssetId: String) {}
    func didUpdateBalance() {}
    func didCreateTransaction() {}
    func didLoadBalance(_: Decimal, asset: AssetInfo) {}
}
