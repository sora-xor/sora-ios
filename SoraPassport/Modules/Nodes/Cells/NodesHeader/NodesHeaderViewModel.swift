/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

protocol NodesHeaderViewModelProtocol {
    var title: String { get }
}

struct NodesHeaderViewModel: NodesHeaderViewModelProtocol {
    var title: String
}

extension NodesHeaderViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return NodesHeaderCell.reuseIdentifier
    }
}
