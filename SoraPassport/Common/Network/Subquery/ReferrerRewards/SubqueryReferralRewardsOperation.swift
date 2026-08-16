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

import RobinHood
import sorawallet
import Foundation

public final class SubqueryReferralRewardsOperation<ResultType>: BaseOperation<ResultType> {
    private let address: String
    private let baseUrl: URL
    private let count: Int

    public init(address: String, count: Int = 1000, baseUrl: URL) {
        self.baseUrl = baseUrl
        self.address = address
        self.count = count

        super.init()
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            guard address.range(
                of: #"^[1-9A-HJ-NP-Za-km-z]+$"#,
                options: .regularExpression
            ) != nil else {
                throw SoraIndexerClientError.invalidResponse
            }

            let nodes: [SoraIndexerReferralNode] = try SoraIndexerClient.fetchEntities(
                from: baseUrl
            ) { cursor in
                """
                query ReferrerRewardsQuery {
                  entities: referrerRewards(
                    first: 100
                    after: "\(cursor)"
                    filter: { referrer: { equalTo: "\(address)" } }
                  ) {
                    nodes { referral amount }
                    pageInfo { hasNextPage endCursor }
                  }
                }
                """
            }
            var rewardsByReferral: [String: String] = [:]
            nodes.prefix(max(0, count)).forEach {
                rewardsByReferral[$0.referral] = $0.amount
            }
            let rewards = rewardsByReferral.map {
                ReferrerReward(referral: $0.key, amount: $0.value)
            }
            let info = ReferrerRewardsInfo(rewards: rewards)
            guard let typedData = info as? ResultType else {
                throw SoraIndexerClientError.resultTypeMismatch
            }
            result = .success(typedData)
        } catch {
            result = .failure(error)
        }
    }
}

private struct SoraIndexerReferralNode: Decodable {
    let referral: String
    let amount: String
}
