protocol RewardSeparatorViewModelProtocol {
}

struct RewardSeparatorViewModel: RewardSeparatorViewModelProtocol {
}

extension RewardSeparatorViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return RewardSeparatorCell.reuseIdentifier
    }
}
