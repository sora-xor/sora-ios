/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/


struct OldNodesViewModel: NodesViewModelProtocol {
    var nodesModels: [NodeViewModel]
    var delegate: NodesCellDelegate?
}

extension OldNodesViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return NodesCell.reuseIdentifier
    }
}
