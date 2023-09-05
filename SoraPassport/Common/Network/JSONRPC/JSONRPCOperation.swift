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
