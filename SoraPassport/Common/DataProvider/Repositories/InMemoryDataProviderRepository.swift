// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
        // TODO: Ivan impl
        return .init()
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
