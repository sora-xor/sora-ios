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
//import RobinHood
//
enum JSONRPCOperationError: Error {
    case timeout
}
//
//class JSONRPCOperation<P: Encodable, T: Decodable>: BaseOperation<T> {
//    let engine: JSONRPCEngine
//    private(set) var requestId: UInt16?
//    let method: String
//    var parameters: P?
//    let timeout: Int
//
//    init(engine: JSONRPCEngine, method: String, parameters: P? = nil, timeout: Int = 30) {
//        self.engine = engine
//        self.method = method
//        self.parameters = parameters
//        self.timeout = timeout
//
//        super.init()
//    }
//
//    override func main() {
//        super.main()
//
//        if isCancelled {
//            return
//        }
//
//        if result != nil {
//            return
//        }
//
//        do {
//            let semaphore = DispatchSemaphore(value: 0)
//
//            var optionalCallResult: Result<T, Error>?
//
//            requestId = try engine.callMethod(method, params: parameters) { (result: Result<T, Error>) in
//                optionalCallResult = result
//
//                semaphore.signal()
//            }
//
//            let status = semaphore.wait(timeout: .now() + .seconds(timeout))
//
//            if status == .timedOut {
//                result = .failure(JSONRPCOperationError.timeout)
//                return
//            }
//
//            guard let callResult = optionalCallResult else {
//                return
//            }
//
//            if
//                case .failure(let error) = callResult,
//                let jsonRPCEngineError = error as? JSONRPCEngineError,
//                jsonRPCEngineError == .clientCancelled {
//                return
//            }
//
//            switch callResult {
//            case .success(let response):
//                result = .success(response)
//            case .failure(let error):
//                result = .failure(error)
//            }
//
//        } catch {
//            result = .failure(error)
//        }
//    }
//
//    override func cancel() {
//        if let requestId = requestId {
//            engine.cancelForIdentifier(requestId)
//        }
//
//        super.cancel()
//    }
//}
//
//final class JSONRPCListOperation<T: Decodable>: JSONRPCOperation<[String], T> {}
