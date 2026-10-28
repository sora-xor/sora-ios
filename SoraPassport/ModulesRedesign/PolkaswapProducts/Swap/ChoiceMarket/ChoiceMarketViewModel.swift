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

import UIKit
import SoraUIKit

import RobinHood
import SoraFoundation

protocol ChoiceMarketViewModelProtocol: AnyObject {
    var selectedMarket: LiquiditySourceType { get set }
    func viewDidLoad()
}

final class ChoiceMarketViewModel {
    
    weak var view: ChoiceMarketViewProtocol?
    var completion: ((LiquiditySourceType) -> Void)?
    var wireframe: AlertPresentable?
    var markets: [LiquiditySourceType]
    var selectedMarket: LiquiditySourceType {
        didSet {
            view?.setup(selectedMarket: selectedMarket)
            completion?(selectedMarket)
        }
    }
    
    init(markets: [LiquiditySourceType], selectedMarket: LiquiditySourceType) {
        self.markets = markets
        self.selectedMarket = selectedMarket
    }
}

extension ChoiceMarketViewModel: ChoiceMarketViewModelProtocol {
    func viewDidLoad() {
        view?.setup(markets: markets)
        view?.setup(selectedMarket: selectedMarket)
    }
}
