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
    static func displayDuration(from seconds: Int) -> String {
        let remainedSeconds = seconds % 60
        let minutes = (seconds / 60) % 60
        let hours = (seconds / 60) / 60

        let result = [minutes, remainedSeconds].map { (value: Int) -> String in
            if value > 9 {
                return String(value)
            } else {
                return "0\(value)"
            }
        }.joined(separator: ":")

        if hours > 0 {
            return "\(hours):\(result)"
        } else {
            return result
        }
    }
}
