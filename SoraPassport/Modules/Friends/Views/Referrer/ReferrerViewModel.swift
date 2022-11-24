/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

protocol ReferrerViewModelProtocol {
    var address: String { get }
    var delegate: ReferrerCellDelegate? { get }
}

struct ReferrerViewModel: ReferrerViewModelProtocol {
    var address: String
    var delegate: ReferrerCellDelegate?
}

extension ReferrerViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return ReferrerCell.reuseIdentifier
    }
}
