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

import Foundation
import SoraFoundation

final class CustomNodePresenter {
    weak var view: CustomNodeViewProtocol?
    var wireframe: Loadable = CustomNodeWireframe()
    var interactor: CustomNodeInteractorInputProtocol!
    var chain: ChainModel

    private var name: String = "" {
        didSet {
            checkCustomNodeInfo()
        }
    }

    private var address: String = "" {
        didSet {
            checkCustomNodeInfo()
        }
    }
    private let mode: NodeAction
    private let node: ChainNodeModel?
    private let completion: ((ChainModel) -> Void)?

    init(chain: ChainModel, mode: NodeAction, completion: ((ChainModel) -> Void)?) {
        self.chain = chain
        self.completion = completion
        self.mode = mode
        if case let .edit(node) = mode {
            self.address = node.url.absoluteString
            self.name = node.name
            self.node = node
        } else {
            self.node = nil
        }
    }
}

// MARK: - Presenter Protocol

extension CustomNodePresenter: CustomNodePresenterProtocol {

    func setup() {
        view?.updateFields(name: self.name, url: self.address)
    }

    func howToRunButtonTapped() {
        guard let url = URL(string: "https://medium.com/sora-xor/how-to-run-a-sora-testnet-node-a4d42a9de1af") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func chestButtonTapped() {
        view?.controller.dismiss(animated: true)
    }

    func customNodeNameChange(to text: String) {
        name = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func customNodeAddressChange(to text: String) {
        address = text
    }

    func submitButtonTapped() {
        guard checkCustomNodeInfo(), let url = URL(string: address) else { return }
        wireframe.showActivityIndicator()
        interactor.updateCustomNode(url: url, name: name)
    }

}

extension CustomNodePresenter: CustomNodeInteractorOutputProtocol {
    func didReceive(error: AddConnectionError) {
        wireframe.hideActivityIndicator()
        if case .noSigningRoute = error {
            // The node is reachable but could not carry a send. Say what is
            // missing instead of calling the address invalid.
            view?.showAddressTextField(Sora2NodeSigningRoute.missingRouteFieldText)
            present(
                message: Sora2NodeSigningRoute.missingRouteMessage,
                title: nil,
                closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                from: view
            )
            return
        }
        view?.showAddressTextField(R.string.localizable.selectNodeInvalidNode(preferredLanguages: .currentLocale))
    }

    func didCompleteAdding(in chain: ChainModel) {
        wireframe.hideActivityIndicator()
        view?.controller.dismiss(animated: true)
        completion?(chain)
    }
}

private extension CustomNodePresenter {
    @discardableResult
    func checkCustomNodeInfo() -> Bool {
        view?.resetState()
        view?.changeSubmitButton(to: false)
        guard !name.isEmpty, !address.isEmpty else { return false }
        let nodes = Array(chain.nodes) + Array(chain.customNodes ?? [])
        let otherNodes = nodes.filter { $0.identifier != node?.identifier }
        guard !otherNodes.contains(where: { $0.name == name }) else {
            view?.showNameTextField(R.string.localizable.selectNodeAlreadyExist(preferredLanguages: .currentLocale))
            return false
        }
        guard let url = URL(string: address), SoraNodeConnectionPolicy.isAllowedEndpoint(url) else {
            view?.showAddressTextField(R.string.localizable.selectNodeInvalidNode(preferredLanguages: .currentLocale))
            return false
        }
        guard !otherNodes.contains(where: { endpointIdentity($0.url) == endpointIdentity(url) }) else {
            view?.showAddressTextField(R.string.localizable.selectNodeAlreadyExist(preferredLanguages: .currentLocale))
            return false
        }
        view?.changeSubmitButton(to: true)
        return true
    }

    func endpointIdentity(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url.absoluteString }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        return components.string ?? url.absoluteString
    }
}


// MARK: - Localizable

extension CustomNodePresenter: Localizable {

    var locale: Locale {
        return localizationManager?.selectedLocale ?? Locale.current
    }

    var languages: [String] {
        return localizationManager?.preferredLocalizations ?? []
    }
}
