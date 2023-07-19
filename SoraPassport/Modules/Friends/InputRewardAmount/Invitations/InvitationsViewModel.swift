import CoreGraphics
import UIKit

protocol InvitationsViewModelProtocol {
    var title: String? { get }
    var description: String { get }
    var fee: Decimal { get }
    var feeSymbol: String { get }
    var balance: String { get }
    var bondedAmount: Decimal { get }
    var buttonTitle: String { get }
    var isEnabled: Bool { get }
    var delegate: InvitationsCellDelegate? { get }
}

class InvitationsViewModel: InvitationsViewModelProtocol {
    var title: String?
    var description: String
    var fee: Decimal
    var feeSymbol: String
    var balance: String
    var bondedAmount: Decimal
    var buttonTitle: String
    var isEnabled: Bool
    var delegate: InvitationsCellDelegate?

    init(title: String?,
         description: String,
         fee: Decimal,
         feeSymbol: String,
         balance: String,
         bondedAmount: Decimal,
         buttonTitle: String,
         isEnabled: Bool,
         delegate: InvitationsCellDelegate?) {
        self.title = title
        self.description = description
        self.fee = fee
        self.feeSymbol = feeSymbol
        self.balance = balance
        self.bondedAmount = bondedAmount
        self.buttonTitle = buttonTitle
        self.isEnabled = isEnabled
        self.delegate = delegate
    }
}

extension InvitationsViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return InvitationsCell.reuseIdentifier
    }
}
