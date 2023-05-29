import Foundation

protocol AmountViewModelProtocol {
    var currentBalance: String { get }
    var bondedAmount: Decimal { get }
    var fee: Decimal { get }
    var delegate: AmountCellDelegate? { get }
}

class AmountViewModel: AmountViewModelProtocol {
    var currentBalance: String
    var bondedAmount: Decimal
    var fee: Decimal
    var delegate: AmountCellDelegate?
    init(currentBalance: String,
         bondedAmount: Decimal,
         fee: Decimal,
         delegate: AmountCellDelegate?) {
        self.currentBalance = currentBalance
        self.bondedAmount = bondedAmount
        self.fee = fee
        self.delegate = delegate
    }
}

extension AmountViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        AmountCell.reuseIdentifier
    }
}
