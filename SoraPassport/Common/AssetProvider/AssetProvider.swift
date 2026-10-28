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

protocol AssetProviderObserverProtocol: AnyObject {
    func processBalance(data: [BalanceData])
}


protocol AssetProviderProtocol: AnyObject {
    func getBalances(with assetIds: [String]) -> [BalanceData]
    func add(observer: AssetProviderObserverProtocol)
    func remove(observer: AssetProviderObserverProtocol)
}

struct AssetProviderObserver {
    weak var observer: AssetProviderObserverProtocol?
}

final class AssetProvider {
    private var balanceData: [BalanceData] = []
    private let balanceProvider: SingleValueProvider<[BalanceData]>?
    private var observers: [AssetProviderObserver] = []
    private let syncQueue = DispatchQueue(label: "co.jp.soramitsu.sora.balance.provider")
    
    init(assetInfos: [AssetInfo], providerFactory: BalanceProviderFactory) {
        balanceProvider = try? providerFactory.createBalanceDataProvider(for: assetInfos, onlyVisible: false)
        setupBalanceDataProvider()
        EventCenter.shared.add(observer: self)
    }
    
    func setupBalanceDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<[BalanceData]>]) -> Void in
            guard let change = changes.first else { return }
            switch change {
            case .insert(let items), .update(let items):
                self?.balanceData = items
                self?.notify()
            default:
                break
            }
        }

        let options = DataProviderObserverOptions()
        balanceProvider?.addObserver(self,
                                    deliverOn: .main,
                                    executing: changesBlock,
                                    failing: { (error: Error) in },
                                    options: options)
    }
}

extension AssetProvider: AssetProviderProtocol {
    func getBalances(with assetIds: [String]) -> [BalanceData] {
        var balances: [BalanceData] = []
        
        for id in assetIds {
            guard let assetBalance = balanceData.first(where: { $0.identifier == id }) else { continue }
            balances.append(assetBalance)
        }

        return balances
    }
    
    func add(observer: AssetProviderObserverProtocol) {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            if !self.observers.contains(where: { $0.observer === observer }) {
                self.observers.append(AssetProviderObserver(observer: observer))
            }
        }
    }

    func remove(observer: AssetProviderObserverProtocol) {
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

                observer.processBalance(data: self.balanceData)
            }
        }
    }
}

extension AssetProvider: EventVisitorProtocol {
    func processBalanceChanged(event: WalletBalanceChanged) {
        balanceProvider?.refresh()
    }
}
