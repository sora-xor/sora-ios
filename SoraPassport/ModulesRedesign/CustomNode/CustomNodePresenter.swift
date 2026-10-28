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
