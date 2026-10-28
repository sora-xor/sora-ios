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

public enum AmountError: Error {
    case invalidStringValue
}

public struct Amount: Codable, Equatable {
    public let decimalValue: Decimal

    public var stringValue: String {
        return (decimalValue as NSNumber).stringValue
    }

    public init(value: Decimal) {
        decimalValue = value
    }

    public init?(string: String) {
        guard let value = Decimal(string: string) else {
            return nil
        }

        self.init(value: value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let stringValue = try container.decode(String.self)

        guard let value = Decimal(string: stringValue) else {
            throw AmountError.invalidStringValue
        }

        decimalValue = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}
