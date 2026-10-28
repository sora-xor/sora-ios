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
