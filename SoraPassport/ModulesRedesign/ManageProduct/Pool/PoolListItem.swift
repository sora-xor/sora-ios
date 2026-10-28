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

final class PoolListItem: NSObject {

    var poolInfo: PoolInfo
    var poolViewModel: PoolViewModel
    var tapHandler: (() -> Void)?
    var favoriteHandle: ((PoolListItem) -> Void)?

    init(poolInfo: PoolInfo, poolViewModel: PoolViewModel) {
        self.poolInfo = poolInfo
        self.poolViewModel = poolViewModel
    }
}

extension PoolListItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PoolListCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }

    var canMove: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        tapHandler?()
    }
}
