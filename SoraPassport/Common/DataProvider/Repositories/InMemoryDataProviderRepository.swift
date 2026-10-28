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

enum InMemoryDataProviderRepositoryError: Error {
    case unsupported
}

final class InMemoryDataProviderRepository<T: Identifiable>: DataProviderRepositoryProtocol {
    func saveBatchOperation(_ updateModelsBlock: @escaping () throws -> [T], _ deleteIdsBlock: @escaping () throws -> [String]) -> RobinHood.BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            let models = try updateModelsBlock()

            var items = self?.itemsById ?? [:]

            for model in models {
                items[model.identifier] = model
            }

            let deletedIds = try deleteIdsBlock()

            for deletedId in deletedIds {
                items[deletedId] = nil
            }

            self?.itemsById = items
        }
    }
    
    func fetchOperation(
        by modelIdsClosure: @escaping () throws -> [String],
        options: RobinHood.RepositoryFetchOptions) -> RobinHood.BaseOperation<[T]>
    {
        ClosureOperation { [weak self] in
            self?.lock.lock()
            defer { self?.lock.unlock() }
            let identifiers = Set(try modelIdsClosure())
            return self?.itemsById.values.filter { identifiers.contains($0.identifier) } ?? []
        }
    }

    typealias Model = T

    private var itemsById: [String: Model] = [:]
    private let lock = NSLock()

    func fetchOperation(
        by modelIdClosure: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<Model?> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            let modelId = try modelIdClosure()
            return self?.itemsById[modelId]
        }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            guard let values = self?.itemsById.values else {
                return []
            }

            return Array(values)
        }
    }

    func fetchOperation(
        by _: RepositorySliceRequest,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        BaseOperation.createWithError(InMemoryDataProviderRepositoryError.unsupported)
    }

    func saveOperation(
        _ updateModelsBlock: @escaping () throws -> [Model],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            let models = try updateModelsBlock()

            var items = self?.itemsById ?? [:]

            for model in models {
                items[model.identifier] = model
            }

            let deletedIds = try deleteIdsBlock()

            for deletedId in deletedIds {
                items[deletedId] = nil
            }

            self?.itemsById = items
        }
    }

    func replaceOperation(_ newModelsBlock: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            let models = try newModelsBlock()

            let newItems = models.reduce(into: [String: Model]()) { result, model in
                result[model.identifier] = model
            }

            self?.itemsById = newItems
        }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            return self?.itemsById.count ?? 0
        }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.lock.lock()

            defer {
                self?.lock.unlock()
            }

            self?.itemsById = [:]
        }
    }
}
