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
import RobinHood
import sorawallet

protocol ConfigServiceProtocol: AnyObject {
    var config: RemoteConfig { get }
    func setupConfig(completion: @escaping () -> Void)
}

struct RemoteConfig {
    var polkaswapIndexerURL: URL
    var subqueryURL: URL { polkaswapIndexerURL }
    var defaultNodes: Set<ChainNodeModel>
    var typesURL: URL?
    
    init(polkaswapIndexerUrlString: String = ApplicationConfig.shared.polkaswapIndexerURL.absoluteString,
         typesUrlString: String? = ApplicationConfig.shared.commonTypesURL?.absoluteString,
         defaultNodes: Set<ChainNodeModel> = ApplicationConfig.shared.defaultChainNodes) {
        self.polkaswapIndexerURL = Self.validHTTPURL(from: polkaswapIndexerUrlString) ?? ApplicationConfig.shared.polkaswapIndexerURL
        self.typesURL = typesUrlString.flatMap(Self.validRuntimeTypesURL)
        self.defaultNodes = Set(defaultNodes.filter { SoraNodeConnectionPolicy.isAllowedEndpoint($0.url) })
    }

    private static func validRuntimeTypesURL(from string: String) -> URL? {
        guard let url = URL(string: string), url.isFileURL,
              url == ApplicationConfig.shared.commonTypesURL else { return nil }
        return url
    }

    private static func validHTTPURL(from string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false else {
            return nil
        }

        return url
    }
}

final class ConfigService {
    static let shared = ConfigService()
    private let operationManager: OperationManager = OperationManager()
    private let configLock = NSLock()
    private var storedConfig = RemoteConfig()

    /// The bundled configuration until the remote one has been answered.
    /// Startup does not wait for that answer, so it can be written while the
    /// chain sync reads the node list: access is locked.
    var config: RemoteConfig {
        get {
            configLock.lock()
            defer { configLock.unlock() }
            return storedConfig
        }
        set {
            configLock.lock()
            storedConfig = newValue
            configLock.unlock()
        }
    }
}

extension ConfigService: ConfigServiceProtocol {

    /// Asks PI for the remote configuration. `completion` is called when the
    /// request has ended, with or without an answer; this can take as long as
    /// the request's own time limits allow, so nothing at launch may wait
    /// for it (see `StartupNetworkCoordinator`).
    func setupConfig(completion: @escaping () -> Void) {
        let queryOperation = SubqueryConfigInfoOperation<SoraConfig>()
        
        queryOperation.completionBlock = { [weak self] in
            guard let self = self, let response = try? queryOperation.extractNoCancellableResultData() else {
                completion()
                return
            }
            // The bundled nodes and type registry always stay. PI may add
            // nodes at other URLs; a URL that is already bundled keeps its
            // bundled entry.
            let bundled = ApplicationConfig.shared.defaultChainNodes
            let bundledURLs = Set(bundled.map(\.url))
            let remote: [ChainNodeModel] = response.nodes.compactMap({ node in
                guard let url = URL(string: node.address), SoraNodeConnectionPolicy.isAllowedEndpoint(url),
                      !bundledURLs.contains(url) else { return nil }
                return ChainNodeModel(url: url, name: node.name, apikey: nil)
            })
            self.config = RemoteConfig(polkaswapIndexerUrlString: ApplicationConfig.shared.polkaswapIndexerURL.absoluteString,
                                       typesUrlString: ApplicationConfig.shared.commonTypesURL?.absoluteString,
                                       defaultNodes: bundled.union(remote))
            completion()
        }
        
        operationManager.enqueue(operations: [queryOperation], in: .blockAfter)
    }
}
