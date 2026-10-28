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

protocol YourReferrerPresenterOutput {}

final class YourReferrerPresenter: YourReferrerPresenterOutput {
    weak var view: YourReferrerViewInput?
    private var items: [CellViewModel] = []
    private var referrer: String
    
    init(referrer: String) {
        self.referrer = referrer
    }
}

extension YourReferrerPresenter: YourReferrerViewOutput {
    func willMove() {
        items.append(YourReferrerViewModel(referrer: referrer,
                                           delegate: self))
        
        DispatchQueue.main.async {
            self.view?.setup(with: self.items)
        }
    }
}

extension YourReferrerPresenter: YourReferrerCellDelegate {
    func closeTapped() {
        self.view?.pop()
    }
}
