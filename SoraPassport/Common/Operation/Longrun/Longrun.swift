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

protocol Longrunable {
    associatedtype ResultType

    func start(with completionClosure: @escaping (Result<ResultType, Error>) -> Void)
    func cancel()
}

final class AnyLongrun<T>: Longrunable {
    typealias ResultType = T

    private let privateStart: (@escaping (Result<ResultType, Error>) -> Void) -> Void
    private let privateCancel: () -> Void

    init<U: Longrunable>(longrun: U) where U.ResultType == ResultType {
        privateStart = longrun.start
        privateCancel = longrun.cancel
    }

    func start(with completionClosure: @escaping (Result<T, Error>) -> Void) {
        privateStart(completionClosure)
    }

    func cancel() {
        privateCancel()
    }
}
