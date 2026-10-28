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
import sorawallet

protocol FiatServiceObserverProtocol: AnyObject {
    func processFiat(data: [FiatData])
}

protocol FiatServiceProtocol: AnyObject {
    func getFiat() async -> [FiatData]
}

struct FiatServiceObserver {
    weak var observer: FiatServiceObserverProtocol?
}

final class FiatService {
    static let shared = FiatService()
    private let operationManager: OperationManager = OperationManager()
    private var expiredDate: Date = Date()
    private var fiatData: [FiatData] = []
    private var observers: [FiatServiceObserver] = []
    private let syncQueue = DispatchQueue(label: "co.jp.soramitsu.sora.fiat.service")

    private func updateFiatData() {
        let queryOperation = SubqueryFiatInfoOperation<[FiatData]>(baseUrl: ConfigService.shared.config.subqueryURL)
        queryOperation.completionBlock = { [weak self] in
            guard let self, let response = try? queryOperation.extractNoCancellableResultData() else {
                return
            }
            self.fiatData = response
            self.expiredDate = Date().addingTimeInterval(20)
        }
        operationManager.enqueue(operations: [queryOperation], in: .transient)
    }
    
    private func updateFiatDataAwait() async -> [FiatData] {
        let queryOperation = SubqueryFiatInfoOperation<[FiatData]>(baseUrl: ConfigService.shared.config.subqueryURL)
        operationManager.enqueue(operations: [queryOperation], in: .transient)

        return await withCheckedContinuation { continuation in
            queryOperation.completionBlock = {
                guard let response = try? queryOperation.extractNoCancellableResultData() else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: response)
            }
        }
    }
    
    private func updateFiatData(with data: [FiatData]) async {
        fiatData = data
        expiredDate = Date().addingTimeInterval(600)
    }
}

extension FiatService: FiatServiceProtocol {
    
    func getFiat() async -> [FiatData] {
        if expiredDate < Date() {
            updateFiatData()
        }
        
        if !fiatData.isEmpty {
            return fiatData
        }
        
        let response = await updateFiatDataAwait()
        await updateFiatData(with: response)
        
        return response
    }
}
