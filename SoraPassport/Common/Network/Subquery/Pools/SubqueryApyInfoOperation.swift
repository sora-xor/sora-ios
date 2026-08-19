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

struct PIExactApyInfo: Equatable, Sendable {
    let id: String
    let pairKey: String?
    let sbApy: PIQuantity?

    init(id: String, pairKey: String? = nil, sbApy: PIQuantity?) {
        self.id = id
        self.pairKey = pairKey
        self.sbApy = sbApy
    }
}

enum SoraApyPairKey {
    static func make(baseAssetId: String, targetAssetId: String) -> String {
        [baseAssetId.lowercased(), targetAssetId.lowercased()]
            .sorted()
            .joined(separator: "|")
    }
}

public final class SubqueryApyInfoOperation<ResultType>: PIAsyncOperation<ResultType> {
    private let client: PIIndexerClient

    public init(baseUrl: URL) {
        client = PIIndexerClient(endpoint: baseUrl)
        super.init()
    }

    override public func execute() async throws -> ResultType {
        let values = try await client.allPoolXYKs().map { pool in
            PIExactApyInfo(
                id: pool.id,
                pairKey: pool.baseAssetId.flatMap { baseAssetId in
                    pool.targetAssetId.map { targetAssetId in
                        SoraApyPairKey.make(
                            baseAssetId: baseAssetId,
                            targetAssetId: targetAssetId
                        )
                    }
                },
                sbApy: pool.strategicBonusApy
            )
        }
        guard let result = values as? ResultType else {
            throw PIIndexerError.invalidResponse
        }
        return result
    }
}
