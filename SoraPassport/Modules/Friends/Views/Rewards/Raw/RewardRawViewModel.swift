import Foundation

protocol RewardRawViewModelProtocol {
}

struct RewardRawViewModel: RewardRawViewModelProtocol {
    var title: String
    var amount: Decimal
    var assetSymbol: String
}

extension RewardRawViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return RewardRawCell.reuseIdentifier
    }
}
