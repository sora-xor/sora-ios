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

//import Foundation
//
//enum JSONRPCEngineError: Error {
//    case emptyResult
//    case remoteCancelled
//    case clientCancelled
//    case unknownError
//}
//
//protocol JSONRPCResponseHandling {
//    func handle(data: Data)
//    func handle(error: Error)
//}
//
//struct JSONRPCRequest: Equatable {
//    let requestId: UInt16
//    let data: Data
//    let options: JSONRPCOptions
//    let responseHandler: JSONRPCResponseHandling?
//
//    static func == (lhs: Self, rhs: Self) -> Bool { lhs.requestId == rhs.requestId }
//}
//
//struct JSONRPCResponseHandler<T: Decodable>: JSONRPCResponseHandling {
//    let completionClosure: (Result<T, Error>) -> Void
//
//    func handle(data: Data) {
//        do {
//            let decoder = JSONDecoder()
//            let response = try decoder.decode(JSONRPCData<T>.self, from: data)
//
//            completionClosure(.success(response.result))
//
//        } catch {
//            completionClosure(.failure(error))
//        }
//    }
//
//    func handle(error: Error) {
//        completionClosure(.failure(error))
//    }
//}
//
//struct JSONRPCOptions {
//    let resendOnReconnect: Bool
//
//    init(resendOnReconnect: Bool = true) {
//        self.resendOnReconnect = resendOnReconnect
//    }
//}
//
//protocol JSONRPCSubscribing: class {
//    var requestId: UInt16 { get }
//    var requestData: Data { get }
//    var requestOptions: JSONRPCOptions { get }
//    var remoteId: String? { get set }
//
//    func handle(data: Data) throws
//    func handle(error: Error, unsubscribed: Bool)
//}
//
//final class JSONRPCSubscription<T: Decodable>: JSONRPCSubscribing {
//    let requestId: UInt16
//    let requestData: Data
//    let requestOptions: JSONRPCOptions
//    var remoteId: String?
//
//    private lazy var jsonDecoder = JSONDecoder()
//
//    let updateClosure: (T) -> Void
//    let failureClosure: (Error, Bool) -> Void
//
//    init(requestId: UInt16,
//         requestData: Data,
//         requestOptions: JSONRPCOptions,
//         updateClosure: @escaping (T) -> Void,
//         failureClosure: @escaping (Error, Bool) -> Void) {
//        self.requestId = requestId
//        self.requestData = requestData
//        self.requestOptions = requestOptions
//        self.updateClosure = updateClosure
//        self.failureClosure = failureClosure
//    }
//
//    func handle(data: Data) throws {
//        let entity = try jsonDecoder.decode(T.self, from: data)
//        updateClosure(entity)
//    }
//
//    func handle(error: Error, unsubscribed: Bool) {
//        failureClosure(error, unsubscribed)
//    }
//}
//
//protocol JSONRPCEngine: class {
//    func callMethod<P: Encodable, T: Decodable>(_ method: String,
//                                                params: P?,
//                                                options: JSONRPCOptions,
//                                                completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16
//
//    func subscribe<P: Encodable, T: Decodable>(_ method: String,
//                                               params: P?,
//                                               updateClosure: @escaping (T) -> Void,
//                                               failureClosure: @escaping  (Error, Bool) -> Void)
//        throws -> UInt16
//
//    func cancelForIdentifier(_ identifier: UInt16)
//
//    //TODO: extend subscriptionFactory instead
//    func generateIdentifier() -> UInt16
//    func addSubscription(_ subscription: JSONRPCSubscribing)
//}
//
//extension JSONRPCEngine {
//    func callMethod<P: Encodable, T: Decodable>(_ method: String,
//                                                params: P?,
//                                                completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
//        try callMethod(method,
//                       params: params,
//                       options: JSONRPCOptions(),
//                       completion: closure)
//    }
//}
