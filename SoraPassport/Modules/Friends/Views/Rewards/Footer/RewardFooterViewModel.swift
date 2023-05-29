protocol RewardFooterViewModelProtocol {
}

struct RewardFooterViewModel: RewardFooterViewModelProtocol {
}

extension RewardFooterViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return RewardFooterCell.reuseIdentifier
    }
}
