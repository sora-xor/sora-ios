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

    private let ws = "wss?:\\/\\/"
    private let port = "(?::\\d{1,5})"
    private let dns = "(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)*[a-z0-9][a-z0-9-]{0,61}[a-z0-9]"
    private let segment = "\\/[a-z0-9-_]+"
    private let ipv4part = "(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]\\d|\\d)"
    private lazy var ipv4 = "\(ipv4part)(?:\\.\(ipv4part)){3}"


    private lazy var wsRegexp = try! NSRegularExpression(pattern: ws)
    private lazy var dnsPathRegexp = try! NSRegularExpression(pattern: "\(dns)\(port)?(\(segment))*")
    private lazy var ipv4Regexp = try! NSRegularExpression(pattern: "\(ipv4)\(port)?(\(segment))*")


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
        name = text
    }

    func customNodeAddressChange(to text: String) {
        address = text
    }

    func submitButtonTapped() {
        guard let url = URL(string: address) else { return }
        wireframe.showActivityIndicator()
        interactor.updateCustomNode(url: url, name: name)
    }

}

extension CustomNodePresenter: CustomNodeInteractorOutputProtocol {
    func didReceive(error: AddConnectionError) {
        wireframe.hideActivityIndicator()
        view?.showAddressTextField(R.string.localizable.selectNodeInvalidNode(preferredLanguages: .currentLocale))
    }

    func didCompleteAdding(in chain: ChainModel) {
        wireframe.hideActivityIndicator()
        view?.controller.dismiss(animated: true)
        completion?(chain)
    }
}

private extension CustomNodePresenter {
    func checkCustomNodeInfo() {
        view?.resetState()

        guard !name.isEmpty, !address.isEmpty else {
            view?.changeSubmitButton(to: false)
            return
        }

        let customNodes = chain.customNodes?.filter { $0.identifier != node?.identifier } ?? []

        guard chain.nodes.first(where: { $0.name == name }) == nil,
              customNodes.first(where: { $0.name == name }) == nil else {
            view?.changeSubmitButton(to: false)
            view?.showNameTextField(R.string.localizable.selectNodeAlreadyExist(preferredLanguages: .currentLocale))
            return
        }

        guard chain.nodes.first(where: { $0.url.absoluteString == address.lowercased() }) == nil,
              customNodes.first(where: { $0.url.absoluteString == address.lowercased() }) == nil else {
            view?.changeSubmitButton(to: false)
            view?.showAddressTextField(R.string.localizable.selectNodeAlreadyExist(preferredLanguages: .currentLocale))
            return
        }
        
        let range = NSRange(location: 0, length: address.count)

        guard wsRegexp.firstMatch(in: address, options: [], range: range) != nil else {
            view?.changeSubmitButton(to: false)
            view?.showAddressTextField(R.string.localizable.selectNodeInvalidNode(preferredLanguages: .currentLocale))
            return
        }

        let withoutSchemeAddress = wsRegexp.stringByReplacingMatches(in: address,
                                                                     options: [],
                                                                     range: range,
                                                                     withTemplate: "")
        let withoutSchemeAddressRange = NSRange(location: 0, length: withoutSchemeAddress.count)

        guard dnsPathRegexp.firstMatch(in: withoutSchemeAddress, options: [], range: withoutSchemeAddressRange) != nil ||
              ipv4Regexp.firstMatch(in: withoutSchemeAddress, options: [], range: withoutSchemeAddressRange) != nil else {
            view?.changeSubmitButton(to: false)
            view?.showAddressTextField(R.string.localizable.selectNodeInvalidNode(preferredLanguages: .currentLocale))
            return
        }

        guard URL(string: address) != nil else {
            view?.changeSubmitButton(to: false)
            view?.showAddressTextField(R.string.localizable.selectNodeInvalidNode(preferredLanguages: .currentLocale))
            return
        }

        view?.changeSubmitButton(to: true)
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
