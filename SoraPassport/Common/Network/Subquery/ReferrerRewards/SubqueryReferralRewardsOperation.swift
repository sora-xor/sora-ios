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

public final class SubqueryReferralRewardsOperation<ResultType>: PIAsyncOperation<ResultType> {
    private let address: String
    private let count: Int
    private let client = PIIndexerClient()

    public init(address: String, count: Int = 1000, baseUrl: URL) {
        self.address = address
        self.count = count
        super.init()
    }

    override public func execute() async throws -> ResultType {
        let limit = min(max(count, 1), 2_000)
        let pageSize = min(100, limit)
        let maximumPages = (limit + pageSize - 1) / pageSize
        let rewards = try await client.allReferrerRewards(
            address: address,
            pageSize: pageSize,
            maximumPages: maximumPages
        ).map { reward in
            guard
                let referral = reward.referral,
                let amount = reward.amount
            else {
                throw PIIndexerError.invalidResponse
            }
            return ReferrerReward(
                referral: referral,
                amount: amount.rawValue
            )
        }

        let legacy = ReferrerRewardsInfo(rewards: rewards)
        guard let result = legacy as? ResultType else {
            throw PIIndexerError.invalidResponse
        }
        return result
    }
}
