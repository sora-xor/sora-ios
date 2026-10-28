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
