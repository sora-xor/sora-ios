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
import SoraUIKit
import CommonWallet
import RobinHood

final class AssetsItem: NSObject {

    var title: String
    var moneyText: String = ""
    
    var assetViewModels: [AssetViewModel] = []
    var isExpand: Bool
    let assetViewModelsFactory: AssetViewModelFactoryProtocol
    weak var fiatService: FiatServiceProtocol?
    var updateHandler: (() -> Void)?
    var expandButtonHandler: (() -> Void)?
    var arrowButtonHandler: (() -> Void)?
    var assetHandler: ((String) -> Void)?
    let debouncer = Debouncer(interval: 0.5)
    let assetProvider: AssetProviderProtocol
    let assetManager: AssetManagerProtocol

    init(title: String,
         isExpand: Bool = true,
         assetProvider: AssetProviderProtocol,
         assetManager: AssetManagerProtocol,
         fiatService: FiatServiceProtocol?,
         assetViewModelsFactory: AssetViewModelFactoryProtocol) {
        self.title = title
        self.isExpand = isExpand
        self.fiatService = fiatService
        self.assetViewModelsFactory = assetViewModelsFactory
        self.assetProvider = assetProvider
        self.assetManager = assetManager
        super.init()
        self.assetProvider.add(observer: self)
    }
    
    public func updateContent() {
        self.fiatService?.getFiat { fiatData in
            let assetIds = self.assetManager.getAssetList()?.filter { $0.visible }.map { $0.assetId } ?? []
            let items = self.assetProvider.getBalances(with: assetIds)
            let fiatDecimal = items.reduce(Decimal(0), { partialResult, balanceData in
                if let priceUsd = fiatData.first(where: { $0.id == balanceData.identifier })?.priceUsd?.decimalValue {
                    return partialResult + balanceData.balance.decimalValue * priceUsd
                }
                return partialResult
            })

            self.moneyText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")

            self.assetViewModels = items.compactMap { item in
                self.assetViewModelsFactory.createAssetViewModel(with: item, fiatData: fiatData, mode: .view)
            }
            self.updateHandler?()
        }
        
    }
}

extension AssetsItem: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        updateContent()
    }
}

extension AssetsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { AssetsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
