/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import BigInt
import Foundation
import SoraKeystore
import UIKit

final class PolkaswapMainPresenter: PolkaswapMainPresenterProtocol {
    weak var view: PolkaswapMainViewProtocol?
    var wireframe: PolkaswapMainWireframeProtocol!
    var interactor: PolkaswapMainInteractorInputProtocol!
    let presenters: [PolkaswapMainPresenterOutputProtocol]
    var selectedTab: PolkaswapTab = .swap

    init(
        swapPresenter: PolkaswapMainPresenterOutputProtocol,
        poolPresenter: PolkaswapMainPresenterOutputProtocol
    ) {
        presenters = [swapPresenter, poolPresenter]
    }
}

extension PolkaswapMainPresenter: PolkaswapMainInteractorOutputProtocol {
    func didBecomeActive(_ active: Bool) {
        if active {
            interactor.setup()
        } else {
            interactor.stop()
        }
    }

    func didCheckPath(fromAssetId: String, toAssetId: String, isAvailable: Bool) {
        presenters.forEach {$0.didCheckPath(fromAssetId: fromAssetId, toAssetId: toAssetId, isAvailable: isAvailable) }
    }

    func didLoadMarketSources(_ marketSources: [String], fromAssetId: String, toAssetId: String) {
        presenters.forEach {$0.didLoadMarketSources(marketSources, fromAssetId: fromAssetId, toAssetId: toAssetId) }
    }

    func didLoadQuote(_ values: SwapValues?, params: PolkaswapMainInteractorQuoteParams) {
        presenters.forEach {$0.didLoadQuote(values, params: params) }
    }

    func didLoadBalance(_ balance: Decimal, asset: AssetInfo) {
        presenters.forEach {$0.didLoadBalance(balance, asset: asset) }
    }

    func didUpdatePoolSubscription() {
        presenters.forEach {$0.didUpdatePoolSubscription() }
    }

    func didUpdateBalance() {
        presenters.forEach {$0.didUpdateBalance(isActiveTab: $0.tab == selectedTab) }
    }

    func didCreateTransaction() {
        presenters.forEach {$0.didCreateTransaction() }
    }

    func didChangeSelectedTab(_ tab: PolkaswapTab) {
        selectedTab = tab
    }
}
