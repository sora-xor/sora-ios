/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol TotalRewardsViewModelProtocol {
    var delegate: TotalRewardsCellDelegate? { get }
}

struct TotalRewardsViewModel: TotalRewardsViewModelProtocol {
    let invetationCount: Int
    let totalRewardsAmount: Decimal
    var assetSymbol: String
    weak var delegate: TotalRewardsCellDelegate?
}

extension TotalRewardsViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return TotalRewardsCell.reuseIdentifier
    }
}
