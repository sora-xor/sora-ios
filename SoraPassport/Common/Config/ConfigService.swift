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
    var subqueryURL: URL
    var defaultNodes: Set<ChainNodeModel>
    var typesURL: URL?
    var isSoraCardEnabled: Bool
    
    init(subqueryUrlString: String = ApplicationConfig.shared.subqueryUrl.absoluteString,
         typesUrlString: String = ApplicationConfig.shared.subqueryUrl.absoluteString,
         defaultNodes: Set<ChainNodeModel> = ApplicationConfig.shared.defaultChainNodes,
         isSoraCardEnabled: Bool = false) {
        self.subqueryURL = URL(string: subqueryUrlString) ?? ApplicationConfig.shared.subqueryUrl
        self.typesURL = URL(string: typesUrlString)
        self.defaultNodes = defaultNodes
        self.isSoraCardEnabled = isSoraCardEnabled
    }
}

final class ConfigService {
    static let shared = ConfigService()
    private let operationManager: OperationManager = OperationManager()
    var config: RemoteConfig = RemoteConfig()
}

extension ConfigService: ConfigServiceProtocol {
    
    func setupConfig(completion: @escaping () -> Void) {
        let queryOperation = SubqueryConfigInfoOperation<SoraConfig>()
        
        queryOperation.completionBlock = { [weak self] in
            guard let self = self, let response = try? queryOperation.extractNoCancellableResultData() else {
                completion()
                return
            }
            let nodes: Set<ChainNodeModel> = Set(response.nodes.compactMap({ node in
                guard let url = URL(string: node.address) else { return nil }
                return ChainNodeModel(url: url, name: node.name, apikey: nil)
            }))
            self.config = RemoteConfig(subqueryUrlString: response.blockExplorerUrl,
                                       typesUrlString: response.substrateTypesUrl,
                                       defaultNodes: nodes,
                                       isSoraCardEnabled: response.soracard)
            completion()
        }
        
        operationManager.enqueue(operations: [queryOperation], in: .blockAfter)
    }
}
