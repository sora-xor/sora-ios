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
import SSFUtils

struct SubqueryErrors: Error, Decodable {
    struct SubqueryError: Error, Decodable {
        let message: String
    }

    let errors: [SubqueryError]
}

enum SubqueryResponse<D: Decodable>: Decodable {
    case data(_ value: D)
    case errors(_ value: SubqueryErrors)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let json = try container.decode(JSON.self)

        if let data = json.data {
            let value = try data.map(to: D.self)
            self = .data(value)
        } else if let errors = json.errors {
            let values = try errors.map(to: [SubqueryErrors.SubqueryError].self)
            self = .errors(SubqueryErrors(errors: values))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unexpected value"
            )
        }
    }
}
