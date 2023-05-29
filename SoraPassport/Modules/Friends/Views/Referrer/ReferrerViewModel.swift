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
