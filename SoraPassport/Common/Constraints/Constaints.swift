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

import UIKit

public extension NSLayoutConstraint {

    var reverse: NSLayoutConstraint {
        constant = -1 * constant
        return self
    }

    var double: NSLayoutConstraint {
        constant = 2 * constant
        return self
    }

    static func activate(_ constraints: [NSLayoutConstraint?]) {
        activate(constraints.compactMap { $0 })
    }

    static func deactivate(_ constraints: [NSLayoutConstraint?]) {
        deactivate(constraints.compactMap { $0 })
    }

    @discardableResult func priority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }

    @discardableResult func priority(_ priority: Float) -> NSLayoutConstraint {
        self.priority = .init(priority)
        return self
    }

    @discardableResult func activate() -> NSLayoutConstraint {
        isActive = true
        return self
    }

    @discardableResult func deactivate() -> NSLayoutConstraint {
        isActive = false
        return self
    }
}
