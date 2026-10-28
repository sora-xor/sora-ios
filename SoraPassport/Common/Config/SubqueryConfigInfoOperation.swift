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
import Foundation
import SoraKeystore

public final class SubqueryConfigInfoOperation<ResultType>: PIAsyncOperation<ResultType> {
    private let client = PIIndexerClient()

    public override init() {
        super.init()
    }

    override public func execute() async throws -> ResultType {
        let capabilitySession = ProductionRemoteCapabilitySession.shared
        // A request in flight is not fresh mutation authority. Read-only
        // cached configuration remains available through its separate paths.
        let refreshToken = capabilitySession.beginLiveRefresh()
        let checkedHealth: PIHealth
        let config: PIMobileConfig
        do {
            // Bind the legacy projection and mutation publication to the
            // exact live health preflight that qualified this config. An
            // independent cached health read could describe another
            // checkpoint and must not be combined with live capabilities.
            let qualified = try await client.qualifiedMobileConfig(
                requireLive: true
            )
            guard
                let qualification = qualified.qualification,
                qualification.source == .live
            else {
                throw PIIndexerError.invalidResponse
            }
            checkedHealth = qualification.health
            config = qualified.value
        } catch {
            // Cached visibility can remain available, but mutation kill
            // switches require a fresh qualified response.
            capabilitySession.invalidate(refreshToken)
            throw error
        }

        let legacy = SoraConfig(
            remote: true,
            blockExplorerUrl: config.blockExplorerUrl.absoluteString,
            blockExplorerType: ConfigExplorerType(
                fiat: "pi",
                reward: "pi",
                sbapy: "pi",
                assets: "pi"
            ),
            nodes: config.nodes.map {
                SoraConfigNode(
                    chain: checkedHealth.chainId,
                    name: $0.name,
                    address: $0.address.absoluteString
                )
            },
            genesis: checkedHealth.genesisHash ?? PIIndexerClient.soraMainnetGenesis,
            joinUrl: "",
            substrateTypesUrl: config.substrateTypesUrl?.absoluteString ?? "",
            soracard: false,
            currencies: []
        )
        guard let result = legacy as? ResultType else {
            throw PIIndexerError.invalidResponse
        }
        // This publishes session-local mutation authority only after the full
        // live response and its legacy projection are accepted.
        guard SettingsManager.shared.applyPIMobileConfig(
            config,
            refreshToken: refreshToken
        ) else {
            throw PIIndexerError.invalidResponse
        }
        return result
    }
}
