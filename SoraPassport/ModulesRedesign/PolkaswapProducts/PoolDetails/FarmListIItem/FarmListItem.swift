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
import SoraUIKit

import RobinHood

final class FarmListItem: ItemProtocol {
    let title: String
    let farmViewModels: [FarmViewModel]
    var tapHandler: ((String) -> Void)?

    init(title: String, farmViewModels: [FarmViewModel], tapHandler: ((String) -> Void)? = nil) {
        self.title = title
        self.farmViewModels = farmViewModels
        self.tapHandler = tapHandler
    }
}

extension FarmListItem: Hashable {
    static func == (lhs: FarmListItem, rhs: FarmListItem) -> Bool {
        lhs.title == rhs.title && lhs.farmViewModels == rhs.farmViewModels
    }
    
    public func hash(into hasher: inout Hasher) {
        return hasher.combine(farmViewModels)
    }
}
