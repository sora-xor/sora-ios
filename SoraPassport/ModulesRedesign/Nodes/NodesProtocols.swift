// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import sorawallet


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
