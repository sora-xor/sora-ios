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

import CoreGraphics
import UIKit
import Combine

protocol InvitationsViewModelProtocol {
    var title: String? { get }
    var description: String { get }
    var fee: Decimal { get }
    var feeSymbol: String { get }
    var balance: String { get }
    var bondedAmount: Decimal { get }
    var buttonTitle: String { get }
    var isEnabled: Bool? { get }
    var delegate: InvitationsCellDelegate? { get }
}

class InvitationsViewModel: InvitationsViewModelProtocol {
    var title: String?
    var description: String
    var fee: Decimal
    var feeSymbol: String
    var balance: String
    var bondedAmount: Decimal
    var buttonTitle: String
    @Published var isEnabled: Bool?
    weak var delegate: InvitationsCellDelegate?

    init(title: String?,
         description: String,
         fee: Decimal,
         feeSymbol: String,
         balance: String,
         bondedAmount: Decimal,
         buttonTitle: String,
         isEnabled: Bool?,
         delegate: InvitationsCellDelegate?) {
        self.title = title
        self.description = description
        self.fee = fee
        self.feeSymbol = feeSymbol
        self.balance = balance
        self.bondedAmount = bondedAmount
        self.buttonTitle = buttonTitle
        self.isEnabled = isEnabled
        self.delegate = delegate
    }
}

extension InvitationsViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return InvitationsCell.reuseIdentifier
    }
}
