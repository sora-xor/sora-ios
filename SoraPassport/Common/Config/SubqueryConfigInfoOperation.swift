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
            soracard: config.soracard,
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
