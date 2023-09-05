// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
