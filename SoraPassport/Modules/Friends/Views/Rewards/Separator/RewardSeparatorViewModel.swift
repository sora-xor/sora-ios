/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

protocol RewardSeparatorViewModelProtocol {
}

struct RewardSeparatorViewModel: RewardSeparatorViewModelProtocol {
}

extension RewardSeparatorViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return RewardSeparatorCell.reuseIdentifier
    }
}
