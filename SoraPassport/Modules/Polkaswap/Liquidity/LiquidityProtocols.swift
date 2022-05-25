import SoraFoundation
import CommonWallet

protocol LiquidityViewProtocol: ControllerBackedProtocol & Localizable {
    func setPercentage(_ value: Int)
    func setFirstAsset(viewModel: PolkaswapAssetViewModel)
    func setSecondAsset(viewModel: PolkaswapAssetViewModel)
    func setFirstAssetBalance(_ balance: String?)
    func setSecondAssetBalance(_ balance: String?)
    func setFirstAmount(_: Decimal)
    func setSecondAmount(_: Decimal)
    func setDetailsEnabled(_ isEnabled: Bool)
    func setDetails(_ detailsState: DetailsState)
    func setNextButton(isEnabled: Bool, title: String)
    func didReceiveDetails(viewModel: PoolDetailsViewModel)
}

protocol LiquidityPresenterProtocol: AnyObject & Localizable {
    var slippage: Double { get set }
    var removePercentageValue: Int { get }
    var mode: TransactionType { get }
    func setup()
    func activateInfo()
    func didSliderMove(_ value: Float)
    func didSelectAmount(_ amount: Decimal?, isFirstAsset: Bool)
    func didSelectPredefinedPercentage(_ percent: Decimal, isFirstAsset: Bool)
    func didPressDetails()
    func didPressSbApyButton()
    func didPressNetworkFee()
    func didPressNextButton()
}

protocol LiquidityInteractorInputProtocol: AnyObject {
    func checkIsAvailable(firstAssetId: String, secondAssetId: String)
    func loadBalance(asset: WalletAsset)
}

protocol LiquidityInteractorOutputProtocol: AnyObject {
    func didCheckAvailable(firstAssetId: String, secondAssetId: String, isAvailable: Bool)
    func didLoadBalance(_ balance: Decimal, asset: WalletAsset)
}

protocol LiquidityWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting {
}

protocol LiquidityFactoryProtocol: AnyObject {
    static func createRemoveLiquidityViewController(
        firstAsset: WalletAsset,
        secondAsset: WalletAsset,
        details: PoolDetails,
        networkFacade: WalletNetworkOperationFactoryProtocol,
        commandFactory: WalletCommandFactoryProtocol,
        amountFormatterFactory: AmountFormatterFactoryProtocol?
    ) -> LiquidityViewController?

    static func createAddLiquidityViewController(
        firstAsset: WalletAsset,
        secondAsset: WalletAsset,
        details: PoolDetails,
        networkFacade: WalletNetworkOperationFactoryProtocol,
        commandFactory: WalletCommandFactoryProtocol,
        amountFormatterFactory: AmountFormatterFactoryProtocol?
    ) -> LiquidityViewController?
}
