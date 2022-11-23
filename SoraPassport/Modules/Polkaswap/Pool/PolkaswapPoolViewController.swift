import Foundation
import Lottie
import SoraFoundation
import UIKit

protocol PolkaswapPoolViewDelegate: AnyObject {
    func onAddPool()
    func onAdd(pool: PoolDetails)
    func onRemove(pool: PoolDetails)
}

class PolkaswapPoolViewController: UIViewController, PolkaswapPoolViewProtocol {
//    weak var delegate: PolkaswapPoolViewDelegate?
    
    private var locale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    var rootView: PolkaswapPoolView {
        view as! PolkaswapPoolView // swiftlint:disable:this force_cast
    }

    private lazy var model = PolkaswapPoolModel(tableView: rootView.tableView, amountFormatterFactory: AmountFormatterFactory())
    var presenter: PolkaswapPoolPresenterProtocol?

    override func loadView() {
        super.loadView()
        view = PolkaswapPoolView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        model.delegate = self

        rootView.onAddPool = { [unowned self] in
            self.onAddPool()
        }
        startLoadingAnimation()
    }

    func startLoadingAnimation() {
        rootView.isUserInteractionEnabled = false
        rootView.loadingView.start()
    }

    func stopLoadingAnimation() {
        rootView.isUserInteractionEnabled = true
        rootView.loadingView.stop()
    }

    func setPoolList(_ pools: [PoolDetails]) {
        model.setPoolList(pools, locale: locale)
        model.delegate = self
        rootView.emptyView.isHidden = !pools.isEmpty
        stopLoadingAnimation()
    }
}

extension PolkaswapPoolViewController: PolkaswapPoolViewDelegate {
    func onAdd(pool: PoolDetails) {
        presenter?.showAddLiquidity(pool)
    }

    func onRemove(pool: PoolDetails) {
        presenter?.showRemoveLiquidity(pool)
    }

    func onAddPool() {
        presenter?.showCreateLiquidity()
    }
}

extension PolkaswapPoolViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.applyLocalization()
        }
    }
}
