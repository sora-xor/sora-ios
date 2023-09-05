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
        interactor.updateCustomNode(url: url, name: name)
    }

}

extension CustomNodePresenter: CustomNodeInteractorOutputProtocol {
    func didReceive(error: AddConnectionError) {
        view?.showAddressTextField(R.string.localizable.selectNodeInvalidNode(preferredLanguages: .currentLocale))
    }

    func didCompleteAdding(in chain: ChainModel) {
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
