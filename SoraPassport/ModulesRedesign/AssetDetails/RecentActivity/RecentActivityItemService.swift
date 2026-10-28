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
import Combine
import BigInt


final class RecentActivityItemService {
    @Published var historyViewModels: [ActivityContentViewModel] = [ ActivityContentViewModel(),
                                                                     ActivityContentViewModel(),
                                                                     ActivityContentViewModel() ]
    
    var updateHandler: (() -> Void)?
    private let assetId: String
    private let historyService: HistoryServiceProtocol
    private let viewModelFactory: ActivityViewModelFactoryProtocol
    private let eventCenter: EventCenterProtocol
    private var assetsProvider: AssetProviderProtocol

    
    init(assetId: String, 
         viewModelFactory: ActivityViewModelFactoryProtocol,
         historyService: HistoryServiceProtocol,
         eventCenter: EventCenterProtocol,
         assetsProvider: AssetProviderProtocol) {
        self.assetId = assetId
        self.historyService = historyService
        self.viewModelFactory = viewModelFactory
        self.eventCenter = eventCenter
        self.assetsProvider = assetsProvider
        self.eventCenter.add(observer: self)
        self.assetsProvider.add(observer: self)
    }
    
    func setup() {
        Task {
            let transactions = ((try? await historyService.getHistory(count: 100, assetId: assetId)) ?? []).prefix(3)
            historyViewModels = transactions.compactMap { viewModelFactory.createActivityViewModel(with: $0) }
            updateHandler?()
        }
    }
}

extension RecentActivityItemService: EventVisitorProtocol {
    func processNewTransaction(event: WalletNewTransactionInserted) {
        setup()
    }
}

extension RecentActivityItemService: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        setup()
    }
}
