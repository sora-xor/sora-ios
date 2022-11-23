
struct OldNodesViewModel: NodesViewModelProtocol {
    var nodesModels: [NodeViewModel]
    var delegate: NodesCellDelegate?
}

extension OldNodesViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return NodesCell.reuseIdentifier
    }
}
