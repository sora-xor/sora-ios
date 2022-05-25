import SoraFoundation
import CommonWallet
import UIKit


protocol SwapViewProtocol: ControllerBackedProtocol & Localizable {
    func setSwapButton(isEnabled: Bool, isLoading: Bool, title: String)
    func setFromAsset(_ asset: WalletAsset?, amount: Decimal?)
    func setToAsset(_ asset: WalletAsset?, amount: Decimal?)
    func setFromAmount(_: Decimal)
    func setToAmount(_: Decimal)
    var marketLabel: UILabel? {get set}
    func didPressMarket()
    func setDetailsExpanded(_: Bool)
    func didReceiveDetails(viewModel: PolkaswapDetailsViewModel)
    func setMarket(type: LiquiditySourceType)
    func setBalance(_ balance: Decimal, asset: WalletAsset, isFrom: Bool)
}

protocol SwapPresenterProtocol: AnyObject {
    var networkFacade: WalletNetworkOperationFactoryProtocol { get set }
    var commandFactory: WalletCommandFactoryProtocol {get set}
    var slippage: Double { get set }
    var isDisclaimerHidden: Bool { get }
    var selectedLiquiditySourceType: LiquiditySourceType { get }
    var assetList: [WalletAsset] { get }
    var poolsDetails: [PoolDetails] { get }
    var currentButtonTitle: String { get }
    func setup(preferredLocalizations languages: [String]?)
    func didSelectAsset(_: WalletAsset?, isFrom: Bool)
    func didSelectAsset(atIndex: Int, isFrom: Bool)
    func didSelectAmount(_: Decimal?, isFrom: Bool)
    func didSelectPredefinedPercentage(_: Decimal, isFrom: Bool)
    func didPressAsset(isFrom: Bool)
    func didPressDetails()
    func didPressInverse()
    func didPressDisclaimer()
    func didPressMarket()
    func didSelectLiquiditySourceType(_ type: LiquiditySourceType)
    func didPressNext()
    func needsUpdateDetails()
}
