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

struct WalletHistoryFilter: OptionSet {
    typealias RawValue = UInt8

    static let transfers = WalletHistoryFilter(rawValue: 1 << 0)
    static let rewardsAndSlashes = WalletHistoryFilter(rawValue: 1 << 1)
    static let extrinsics = WalletHistoryFilter(rawValue: 1 << 2)
    static let all: WalletHistoryFilter = [.transfers, .rewardsAndSlashes, .extrinsics]

    let rawValue: UInt8

    init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

extension WalletHistoryFilter {
    init(string: String?) {
        if let string = string, let filterValue = UInt8(string) {
            self.init(rawValue: filterValue)
        } else {
            self = .all
        }
    }

    func toString() -> String { String(rawValue) }
}
