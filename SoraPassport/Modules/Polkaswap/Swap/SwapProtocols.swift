/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import SoraFoundation
import CommonWallet
import UIKit


protocol SwapViewProtocol: ControllerBackedProtocol & Localizable {
    func setSwapButton(isEnabled: Bool, isLoading: Bool, title: String)
    func setFromAsset(_ asset: AssetInfo?, amount: Decimal?)
    func setToAsset(_ asset: AssetInfo?, amount: Decimal?)
    func setFromAmount(_: Decimal)
    func setToAmount(_: Decimal)
    func setSlippageAmount(_: Decimal)
    var marketLabel: UILabel? {get set}
    func didPressMarket()
    func setDetailsExpanded(_: Bool)
    func didReceiveDetails(viewModel: PolkaswapDetailsViewModel)
    func setMarket(type: LiquiditySourceType)
    func setBalance(_ balance: Decimal, asset: AssetInfo, isFrom: Bool)
}

protocol SwapPresenterProtocol: AnyObject {
    var networkFacade: WalletNetworkOperationFactoryProtocol { get set }
    var commandFactory: WalletCommandFactoryProtocol {get set}
    var slippage: Double { get set }
    var isDisclaimerHidden: Bool { get }
    var selectedLiquiditySourceType: LiquiditySourceType { get }
    var assetList: [AssetInfo] { get }
    var poolsDetails: [PoolDetails] { get }
    var currentButtonTitle: String { get }
    func setup(preferredLocalizations languages: [String]?)
    func didSelectAsset(_: AssetInfo?, isFrom: Bool)
    func didSelectAsset(atIndex: Int, isFrom: Bool)
    func didSelectAmount(_: Decimal?, isFrom: Bool)
    func didSelectPredefinedPercentage(_: Decimal, isFrom: Bool)
    func didPressAsset(isFrom: Bool)
    func didPressDetails()
    func didPressInverse()
    func didPressDisclaimer()
    func didPressMarket()
    func didPressNext()
    func didUpdateLocale()
    func showSlippageController()
}

protocol PolkaswapSwapFactoryProtocol: AnyObject {
    func createAssetViewModel(asset: AssetInfo?, amount: Decimal?, locale: Locale) -> PolkaswapAssetViewModel
}
