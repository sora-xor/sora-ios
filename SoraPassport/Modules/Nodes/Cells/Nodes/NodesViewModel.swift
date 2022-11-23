protocol NodesViewModelProtocol {
    var nodesModels: [NodeViewModel] { get }
    var delegate: NodesCellDelegate? { get }
}

struct NodesViewModel: NodesViewModelProtocol {
    var nodesModels: [NodeViewModel]
    var header: String
    var delegate: NodesCellDelegate?
}

struct NodeViewModel {
    let node: ChainNodeModel
    let isSelected: Bool
    let isCustom: Bool
}

extension NodesViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return NodesCell.reuseIdentifier
    }
}

struct SectionViewModel {
    let header: NodesHeaderViewModelProtocol
    let models: NodesViewModel
}
