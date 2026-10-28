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

import sorawallet
import SoraFoundation

// MARK: - View

protocol CustomNodeViewProtocol: ControllerBackedProtocol {
    func changeSubmitButton(to isEnabled: Bool)
    func showNameTextField(_ error: String)
    func showAddressTextField(_ error: String)
    func updateFields(name: String, url: String)
    func resetState()
}

// MARK: - Presenter

protocol CustomNodePresenterProtocol: AlertPresentable {
    func setup()
    func chestButtonTapped()
    func howToRunButtonTapped()
    func customNodeNameChange(to text: String)
    func customNodeAddressChange(to text: String)
    func submitButtonTapped()
}

// MARK: - Interactor

protocol CustomNodeInteractorInputProtocol: AnyObject {
    func updateCustomNode(url: URL, name: String)
}

protocol CustomNodeInteractorOutputProtocol: AnyObject {
    func didCompleteAdding(in chain: ChainModel)
    func didReceive(error: AddConnectionError)
}

// MARK: - Wireframe

protocol CustomNodeWireframeProtocol {
    func showRoot()
    func showAddCustomNode()
}

// MARK: - Factory

protocol CustomNodeViewFactoryProtocol: AnyObject {
    static func createView() -> CustomNodeViewProtocol?
}
