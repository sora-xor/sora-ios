/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import XNetworking
import CommonWallet

// MARK: - View

protocol NodesViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func setup(with models: [SectionViewModel])
    func reloadScreen(with models: [SectionViewModel], updatedIndexs: [Int], isExpanding: Bool)
}

// MARK: - Presenter

protocol NodesPresenterProtocol: AlertPresentable {
    func setup()
}

// MARK: - Interactor

protocol NodesInteractorInputProtocol: AnyObject {
    var chain: ChainModel { get set }
    func setup()
    func changeSelectedNode(to node: ChainNodeModel)
    func removeNode(_ node: ChainNodeModel)
}

protocol NodesInteractorOutputProtocol: AnyObject {
    func didReceive(chain: ChainModel)
    func showConnectionFailed()
    func restart()
}

// MARK: - Wireframe

protocol NodesWireframeProtocol {
    func showRoot()
    func showCustomNode(from controller: UIViewController, chain: ChainModel, action: NodeAction, completion: ((ChainModel) -> Void)?)
}

// MARK: - Factory

protocol NodesViewFactoryProtocol: AnyObject {
    static func createView() -> NodesViewProtocol?
}
