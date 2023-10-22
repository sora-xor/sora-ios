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
import sorawallet

protocol FiatServiceObserverProtocol: AnyObject {
    func processFiat(data: [FiatData])
}

protocol FiatServiceProtocol: AnyObject {
    func getFiat(completion: @escaping ([FiatData]) -> Void)
    func getFiat() async -> [FiatData]
    func add(observer: FiatServiceObserverProtocol)
    func remove(observer: FiatServiceObserverProtocol)
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
    private var task: Task<Void, Swift.Error>?

    private func updateFiatData() async -> [FiatData] {
        return await withCheckedContinuation { continuation in
            let queryOperation = SubqueryFiatInfoOperation<[FiatData]>(baseUrl: ConfigService.shared.config.subqueryURL)
            
            queryOperation.completionBlock = { [weak self] in
                guard let self = self, let response = try? queryOperation.extractNoCancellableResultData() else {
                    continuation.resume(returning: [])
                    return
                }
                self.fiatData = response
                self.expiredDate = Date().addingTimeInterval(600)
                self.notify()
                continuation.resume(returning: response)
            }
            
            operationManager.enqueue(operations: [queryOperation], in: .transient)
        }
    }
}

extension FiatService: FiatServiceProtocol {
    
    func getFiat(completion: @escaping ([FiatData]) -> Void) {
        task?.cancel()
        task = Task {
            guard expiredDate < Date() || fiatData.isEmpty else {
                completion(fiatData)
                return
            }

            let fiatData = await updateFiatData()
            completion(fiatData)
        }
    }
    
    func getFiat() async -> [FiatData] {
        return await withCheckedContinuation { continuation in
            task?.cancel()
            task = Task {
                guard expiredDate < Date() || fiatData.isEmpty else {
                    continuation.resume(with: .success(fiatData))
                    return
                }
                
                let fiatData = await self.updateFiatData()
                continuation.resume(with: .success(fiatData))
            }
        }
    }
    
    func add(observer: FiatServiceObserverProtocol) {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            if !self.observers.contains(where: { $0.observer === observer }) {
                self.observers.append(FiatServiceObserver(observer: observer))
            }
        }
    }

    func remove(observer: FiatServiceObserverProtocol) {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer != nil && $0.observer !== observer }
        }
    }
    
    func notify() {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            for wrapper in self.observers {
                guard let observer = wrapper.observer else {
                    continue
                }

                observer.processFiat(data: self.fiatData)
            }
        }
    }
}
