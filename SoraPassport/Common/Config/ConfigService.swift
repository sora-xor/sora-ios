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
