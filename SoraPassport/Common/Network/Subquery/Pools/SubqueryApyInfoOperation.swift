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

import sorawallet
import Foundation

struct PIExactApyInfo: Equatable, Sendable {
    let id: String
    let sbApy: PIQuantity?
}

public final class SubqueryApyInfoOperation<ResultType>: PIAsyncOperation<ResultType> {
    private let baseUrl: URL
    private let catalog: () async throws -> [PIPoolXYK]

    public convenience init(baseUrl: URL) {
        self.init(baseUrl: baseUrl) { try await PICatalogs.pools.values() }
    }

    init(baseUrl: URL, catalog: @escaping () async throws -> [PIPoolXYK]) {
        self.baseUrl = baseUrl
        self.catalog = catalog
        super.init()
    }

    override public func execute() async throws -> ResultType {
        // The shared catalog reads the reviewed production PI only.
        try PIIndexerClient.validateProductionEndpoint(baseUrl)
        let values = try await catalog().map { pool in
            PIExactApyInfo(
                id: pool.id,
                sbApy: pool.strategicBonusApy
            )
        }
        guard let result = values as? ResultType else {
            throw PIIndexerError.invalidResponse
        }
        return result
    }
}
