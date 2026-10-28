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
import SSFUtils

extension ChainData {
    var stringValue: String? {
        switch self {
        case .none:
            return nil
        case .raw(let data):
            return String(data: data, encoding: .utf8)
        case .blakeTwo256(let data), .keccak256(let data),
             .sha256(let data), .shaThree256(let data):
            return data.value.toHex(includePrefix: true)
        }
    }

    var imageValue: UIImage? {
        if case .raw(let data) = self {
            return UIImage(data: data)
        } else {
            return nil
        }
    }

    var dataValue: Data? {
        switch self {
        case .none:
            return nil
        case .raw(let data):
            return data
        case .blakeTwo256(let hash), .keccak256(let hash),
             .sha256(let hash), .shaThree256(let hash):
            return hash.value
        }
    }
}
