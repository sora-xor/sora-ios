/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

protocol PolkaswapMainViewProtocol: ControllerBackedProtocol {
}

protocol PolkaswapMainPresenterProtocol: AnyObject {
    func didBecomeActive(_ : Bool)
    func didChangeSelectedTab(_: PolkaswapTab)
}

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
    func didLoadQuote(_: SwapValues?, params: PolkaswapMainInteractorQuoteParams)
    func didLoadBalance(_: Decimal, asset: AssetInfo)
    func didUpdatePoolSubscription()
    func didUpdateBalance()
    func didCreateTransaction()
}

protocol PolkaswapMainPresenterOutputProtocol: PolkaswapMainInteractorOutputProtocol {
    var tab: PolkaswapTab { get }
    func didUpdateBalance(isActiveTab: Bool)
}


protocol PolkaswapMainWireframeProtocol: AnyObject {
}

protocol PolkaswapMainViewFactoryProtocol: AnyObject {
    // we use walletContext to get shared commands and network functionality from there
    static func createView(walletContext: CommonWalletContextProtocol, polkaswapContext: PolkaswapNetworkOperationFactoryProtocol) -> PolkaswapMainViewProtocol?
}
