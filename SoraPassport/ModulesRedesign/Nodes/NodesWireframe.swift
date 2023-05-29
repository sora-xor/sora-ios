import Foundation
import UIKit

final class NodesWireframe: NodesWireframeProtocol {


    func showCustomNode(from controller: UIViewController, chain: ChainModel, action: NodeAction, completion: ((ChainModel) -> Void)?) {
        guard let viewController = NodesViewFactory.customNodeView(with: chain, mode: action, completion: completion) else {
            return
        }
        controller.navigationController?.pushViewController(viewController as! UIViewController, animated: true)
    }

    func showRoot() {
        guard let rootWindow = UIApplication.shared.delegate?.window as? SoraWindow else {
            fatalError()
        }

        _ = SplashPresenterFactory.createSplashPresenter(with: rootWindow)
    }
}
