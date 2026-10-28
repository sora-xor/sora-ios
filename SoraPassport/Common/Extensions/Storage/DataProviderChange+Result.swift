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
import RobinHood

extension DataProviderChange {
    var item: T? {
        switch self {
        case .insert(let newItem), .update(let newItem):
            return newItem
        case .delete:
            return nil
        }
    }

    static func change<P: Identifiable & Equatable> (value1: P?, value2: P?)
        -> DataProviderChange<P>? {
        guard let currentItem = value1 else {
            if let newItem = value2 {
                return DataProviderChange<P>.insert(newItem: newItem)
            } else {
                return nil
            }
        }

        guard let newItem = value2 else {
            return DataProviderChange<P>.delete(deletedIdentifier: currentItem.identifier)
        }

        if newItem != currentItem {
            return DataProviderChange<P>.update(newItem: newItem)
        } else {
            return nil
        }
    }
}
