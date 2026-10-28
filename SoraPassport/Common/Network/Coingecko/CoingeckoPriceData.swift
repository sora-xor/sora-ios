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


struct CoingeckoPriceData: Codable, Equatable {
    let usdPrice: Decimal
    let usdDayChange: Decimal?
    let lastUpdatedAt: Int64?

    func isUsable(at now: Date = Date()) -> Bool {
        // An HTTP success can contain a delisted token's zero or stale quote.
        guard !usdPrice.isNaN, usdPrice > 0, let lastUpdatedAt else { return false }
        let age = now.timeIntervalSince1970 - TimeInterval(lastUpdatedAt)
        return age >= -60 && age <= 15 * 60
    }

    enum CodingKeys: String, CodingKey {
        case usdPrice = "usd"
        case usdDayChange = "usd_24h_change"
        case lastUpdatedAt = "last_updated_at"
    }
}
