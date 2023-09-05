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

enum OperationCombiningServiceError: Error {
    case alreadyRunningOrFinished
}

final class OperationCombiningService<T>: Longrunable {
    enum State {
        case waiting
        case running
        case finished
    }

    typealias ResultType = [T]

    let operationsClosure: () throws -> [CompoundOperationWrapper<T>]
    let operationManager: OperationManagerProtocol

    private(set) var state: State = .waiting

    private var wrappers: [CompoundOperationWrapper<T>]?

    init(
        operationManager: OperationManagerProtocol,
        operationsClosure: @escaping () throws -> [CompoundOperationWrapper<T>]
    ) {
        self.operationManager = operationManager
        self.operationsClosure = operationsClosure
    }

    func start(with completionClosure: @escaping (Result<ResultType, Error>) -> Void) {
        guard state == .waiting else {
            completionClosure(.failure(OperationCombiningServiceError.alreadyRunningOrFinished))
            return
        }

        state = .waiting

        do {
            let wrappers = try operationsClosure()

            let mapOperation = ClosureOperation<ResultType> {
                try wrappers.map { try $0.targetOperation.extractNoCancellableResultData() }
            }

            mapOperation.completionBlock = { [weak self] in
                self?.state = .finished
                self?.wrappers = nil

                do {
                    let result = try mapOperation.extractNoCancellableResultData()
                    completionClosure(.success(result))
                } catch {
                    completionClosure(.failure(error))
                }
            }

            let dependencies = wrappers.flatMap(\.allOperations)
            dependencies.forEach { mapOperation.addDependency($0) }

            operationManager.enqueue(operations: dependencies + [mapOperation], in: .transient)

        } catch {
            completionClosure(.failure(error))
        }
    }

    func cancel() {
        if state == .running {
            wrappers?.forEach { $0.cancel() }
            wrappers = nil
        }

        state = .finished
    }
}

extension OperationCombiningService {
    func longrunOperation() -> LongrunOperation<[T]> {
        LongrunOperation(longrun: AnyLongrun(longrun: self))
    }
}
