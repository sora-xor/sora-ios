/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit

final class NodesWireframe: NodesWireframeProtocol {


    func showCustomNode(from controller: UIViewController, chain: ChainModel, action: NodeAction, completion: ((ChainModel) -> Void)?) {
        let isNeedRedesign = ApplicationConfig.shared.isNeedRedesign

        if isNeedRedesign {
            guard let viewController = NodesViewFactory.customNodeView(with: chain, mode: action, completion: completion) else {
                return
            }
            controller.navigationController?.pushViewController(viewController as! UIViewController, animated: true)
        } else {
            guard let viewController = NodesViewFactory.customOldNodeView(with: chain, mode: action, completion: completion) else {
                return
            }
            controller.present(viewController.controller, animated: true, completion: nil)
        }
    }

    func showRoot() {
        guard let rootWindow = UIApplication.shared.delegate?.window as? SoraWindow else {
            fatalError()
        }

        _ = SplashPresenterFactory.createSplashPresenter(with: rootWindow)
    }
}
