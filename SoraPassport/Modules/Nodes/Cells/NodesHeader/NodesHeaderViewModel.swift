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
