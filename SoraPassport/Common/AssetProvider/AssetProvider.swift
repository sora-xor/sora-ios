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
import CommonWallet

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
    
    init(assetManager: AssetManagerProtocol, providerFactory: BalanceProviderFactory) {
        balanceProvider = try? providerFactory.createBalanceDataProvider(for: assetManager.getAssetList() ?? [], onlyVisible: false)
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
