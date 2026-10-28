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
import SoraUIKit

import RobinHood

final class AssetsItem: NSObject {

    var title: String
    
    var isExpand: Bool
    var updateHandler: (() -> Void)?
    var expandButtonHandler: (() -> Void)?
    var arrowButtonHandler: (() -> Void)?
    var assetHandler: ((String) -> Void)?
    let assetProvider: AssetProviderProtocol
    var service: AssetsItemService?

    init(title: String,
         isExpand: Bool = true,
         assetProvider: AssetProviderProtocol,
         service: AssetsItemService?) {
        self.service = service
        self.title = title
        self.isExpand = isExpand
        self.assetProvider = assetProvider
        super.init()
        self.assetProvider.add(observer: self)
    }
    
    public func updateContent() {
        service?.setup()
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
