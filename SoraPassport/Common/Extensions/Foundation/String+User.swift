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

extension String {
    var firstName: String? {
        let components = self.components(separatedBy: CharacterSet.whitespaces)

        guard components.count > 0 else {
            return nil
        }

        if components.count == 1 {
            return components[0]
        } else {
            return components[0..<(components.count - 1)].joined(separator: " ")
        }
    }

    var lastName: String? {
        let components = self.components(separatedBy: CharacterSet.whitespaces)

        guard components.count > 1 else {
            return nil
        }

        return components[components.count - 1]
    }

    var soraConcat: String {
        if self.count < 11 {return self}
        let prefix = self.prefix(5)
        let suffix = self.suffix(5)
        return "\(prefix)…\(suffix)"
    }
}
