import CommonWallet
import Foundation
import Lottie
import SoraFoundation
import UIKit

protocol PolkaswapPoolViewDelegate: AnyObject {
    func onAddPool()
    func onAdd(pool: PoolDetails)
    func onRemove(pool: PoolDetails)
}

class PolkaswapPoolViewController: UIViewController & PolkaswapPoolViewProtocol {
//    weak var delegate: PolkaswapPoolViewDelegate?

    var rootView: PolkaswapPoolView {
        view as! PolkaswapPoolView // swiftlint:disable:this force_cast
    }

    private lazy var model = PolkaswapPoolModel(tableView: rootView.tableView)
    var presenter: PolkaswapPoolPresenter?

    override func loadView() {
        super.loadView()
        view = PolkaswapPoolView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
#if F_RELEASE || F_TEST
        let placeholder = PolkaswapPoolPlaceholderView()
        placeholder.localizationManager = localizationManager
        if let cover = placeholder.view {
               cover.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(cover)
               cover.widthAnchor.constraint(equalTo: rootView.widthAnchor).isActive = true
               cover.heightAnchor.constraint(equalTo: rootView.heightAnchor).isActive = true
        }
#endif
        model.delegate = self

        rootView.onAddPool = { [unowned self] in
            self.onAddPool()
        }

        rootView.loadingView.start()
    }

    func setPoolList(_ pools: [PoolDetails]) {
        model.setPoolList(pools)
        rootView.loadingView.stop()
        rootView.emptyView.isHidden = !pools.isEmpty
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
//        presenter.showAddPool()
    }

 
}

extension PolkaswapPoolViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.applyLocalization()
        }
    }
}
