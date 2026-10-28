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


final class HeaderActivityDetailsItem: NSObject {

    let typeText: String
    let typeTransactionImage: UIImage?
    let actionTransactionImage: UIImage?
    let firstAssetImageViewModel: UIImage?
    let secondAssetImageViewModel: UIImage?
    let firstBalanceText: NSAttributedString
    let secondBalanceText: NSAttributedString?
    var details: [DetailViewModel]

    init(typeText: String,
         typeTransactionImage: UIImage?,
         actionTransactionImage: UIImage? = nil,
         firstAssetImageViewModel: UIImage?,
         secondAssetImageViewModel: UIImage? = nil,
         firstBalanceText: NSAttributedString,
         secondBalanceText: NSAttributedString? = nil,
         details: [DetailViewModel]) {
        self.typeText = typeText
        self.typeTransactionImage = typeTransactionImage
        self.actionTransactionImage = actionTransactionImage
        self.firstAssetImageViewModel = firstAssetImageViewModel
        self.secondAssetImageViewModel = secondAssetImageViewModel
        self.firstBalanceText = firstBalanceText
        self.secondBalanceText = secondBalanceText
        self.details = details
    }
}

extension HeaderActivityDetailsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { HeaderActivityDetailsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
