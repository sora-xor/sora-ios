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

struct CurrencyItemData: Codable, Equatable {
    var code: String
    var name: String
    var symbol: String
    var ratio: String
}

struct CurrencyData: Codable, Equatable {
    var sectionName: String
    var topics: [String: CurrencyItemData]
}

extension CurrencyData {
    func sortedItems() -> [CurrencyItemData] {
        return topics.enumerated().sorted(by: { (firstItem, secondItem) in
            let firstIndex = Int(firstItem.element.key) ?? 0
            let secondIndex = Int(secondItem.element.key) ?? 0

            return firstIndex < secondIndex
        })
            .map({ $0.element.value })
    }
}
