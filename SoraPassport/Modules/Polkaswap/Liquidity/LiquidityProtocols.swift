/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import SoraFoundation
import CommonWallet

//swiftlint:disable function_parameter_count

protocol LiquidityViewProtocol: ControllerBackedProtocol, Localizable {
    func setPercentage(_ value: Int)
    func setSliderAmount(_ amount: Int)
    func setFirstAsset(viewModel: PolkaswapAssetViewModel)
    func setSecondAsset(viewModel: PolkaswapAssetViewModel)
    func setFirstAssetBalance(_ balance: String?)
    func setSecondAssetBalance(_ balance: String?)
    func setSlippageAmount(_: Decimal)
    func setFirstAmount(_: Decimal)
    func setSecondAmount(_: Decimal)
    func setDetailsVisible(_ isEnabled: Bool)
    func setDetails(_ detailsState: DetailsState)
    func setNextButton(isEnabled: Bool, isLoading: Bool, title: String)
    func didReceiveDetails(viewModel: PoolDetailsViewModel)
    func setFirstProviderView(isHidden: Bool)
}

protocol LiquidityPresenterProtocol: LiquidityInteractorOutputProtocol, Localizable {
    var view: LiquidityViewProtocol? { get set }
    var wireframe: LiquidityWireframeProtocol! { get set }
    var interactor: LiquidityInteractorInputProtocol! { get set }
    var amountFormatterFactory: AmountFormatterFactoryProtocol? { get set }

    var slippage: Double { get set }
    var removePercentageValue: Int { get }
    var isAddingLiquidity: Bool { get }
    func setup()
    func activateInfo()
    func didSliderMove(_ value: Float)
    func didSelectAmount(_ amount: Decimal?, isFirstAsset: Bool)
    func didSelectPredefinedPercentage(_ percent: Decimal, isFirstAsset: Bool)
    func didPressAsset(isFrom: Bool)
    func didPressDetails()
    func didPressSbApyButton()
    func didPressNetworkFee()
    func didPressNextButton()
    func showSlippageController()
    func didLoadPools(_ pools: [PoolDetails])
}

protocol LiquidityInteractorInputProtocol: AnyObject {
    var isLoading: Bool { get }
    func networkFeeValue(with type: TransactionType, completion: @escaping (Decimal) -> Void)
    func checkIsPairExists(baseAsset: String, targetAsset: String)
    func loadBalance(asset: AssetInfo)
    func loadPool(baseAsset: String, targetAsset: String)
    func subscribePoolReserves(asset: String)
}

protocol LiquidityInteractorOutputProtocol: AnyObject {
    func didCheckIsPairExists(baseAsset: String, targetAsset: String, isExists: Bool)
    func didLoadBalance(_ balance: Decimal, asset: AssetInfo)
    func didLoadPoolDetails(_ poolDetails: PoolDetails?, baseAsset: String, targetAsset: String)
    func didUpdatePoolSubscription(asset: String)
}

protocol LiquidityWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting {
}

protocol LiquidityFactoryProtocol: AnyObject {
    
    static func createLiquidityViewController(
        assets: [AssetInfo],
        firstAsset: AssetInfo,
        activePoolsList: [PoolDetails],
        networkFacade: WalletNetworkOperationFactoryProtocol,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
        commandFactory: WalletCommandFactoryProtocol,
        amountFormatterFactory: AmountFormatterFactoryProtocol?
    ) -> LiquidityViewController?

    static func createRemoveLiquidityViewController(
        firstAsset: AssetInfo,
        secondAsset: AssetInfo,
        details: PoolDetails,
        activePoolsList: [PoolDetails],
        networkFacade: WalletNetworkOperationFactoryProtocol,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
        commandFactory: WalletCommandFactoryProtocol,
        amountFormatterFactory: AmountFormatterFactoryProtocol?
    ) -> LiquidityViewController?

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
    ) -> LiquidityViewController?
}
