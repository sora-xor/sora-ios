import Foundation
import SoraFoundation
import UIKit
import CommonWallet

class PolkaswapPoolPlaceholderView: UIViewController, PolkaswapPoolViewProtocol {
    var presenter: PolkaswapPoolPresenterProtocol? {
        return self as? PolkaswapPoolPresenterProtocol
    }    
    var delegate: PolkaswapPoolViewDelegate?

    @IBOutlet var comingSoonLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.translatesAutoresizingMaskIntoConstraints = false

        view.backgroundColor = R.color.neumorphism.base()
        comingSoonLabel.font = UIFont.styled(for: .title1, isBold: true)
        applyLocalization()
    }

    func setPoolList(_ pools: [PoolDetails]) { }
}

extension PolkaswapPoolPlaceholderView: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        comingSoonLabel?.text = R.string.localizable.comingSoon(preferredLanguages: languages)
    }
}

extension PolkaswapPoolPlaceholderView: PolkaswapPoolPresenterProtocol {
    var tab: PolkaswapTab { return .pool }
    func showAddLiquidity(_ pool: PoolDetails) { }
    func showRemoveLiquidity(_ pool: PoolDetails) { }
    func showCreateLiquidity() { }
    func didCheckPath(fromAssetId: String, toAssetId: String, isAvailable: Bool) { }
    func didLoadMarketSources(_: [String], fromAssetId: String, toAssetId: String) { }
    func didLoadQuote(_: SwapValues?, params: PolkaswapMainInteractorQuoteParams) { }
    func didLoadBalance(_: Decimal, asset: AssetInfo) { }
    func didLoadPools(_ pools: [PoolDetails]) { }
    func didUpdatePoolSubscription() { }
    func didUpdateBalance() {}
    func didUpdateBalance(isActiveTab: Bool) { }
    func didCreateTransaction() { }
    func didUpdateAccountPools() { }
    func didUpdateAccountPoolReserves(baseAsset: String, targetAsset: String) { }
}
