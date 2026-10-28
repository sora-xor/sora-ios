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

final class ConfirmAssetViewModel {
    let imageViewModel: WalletImageViewModelProtocol?
    var amountText: String
    let symbol: String
    
    init(imageViewModel: WalletImageViewModelProtocol?, amountText: String, symbol: String) {
        self.imageViewModel = imageViewModel
        self.amountText = amountText
        self.symbol = symbol
    }
}

final class ConfirmAssetsItem: NSObject {
    
    let firstAssetImageModel: ConfirmAssetViewModel
    let secondAssetImageModel: ConfirmAssetViewModel
    let operationImageName: String
    
    init(firstAssetImageModel: ConfirmAssetViewModel,
         secondAssetImageModel: ConfirmAssetViewModel,
         operationImageName: String) {
        self.firstAssetImageModel = firstAssetImageModel
        self.secondAssetImageModel = secondAssetImageModel
        self.operationImageName = operationImageName
    }
}

extension ConfirmAssetsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { ConfirmAssetsCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
}
