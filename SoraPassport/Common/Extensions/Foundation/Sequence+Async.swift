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

extension Sequence {
    func asyncCompactMap<T>(
         _ transform: (Element) async throws -> T?
     ) async rethrows -> [T] {
         var values = [T]()

         for element in self {
             guard let value = try await transform(element) else {
                 continue
             }

             values.append(value)
         }

         return values
     }
    
    func concurrentMap<T>(
        _ transform: @escaping (Element) async throws -> T?
    ) async throws -> [T] {
        let tasks = compactMap { element in
            Task {
                try await transform(element)
            }
        }
        
        return try await tasks.asyncCompactMap { task in
            try await task.value
        }
    }
}
