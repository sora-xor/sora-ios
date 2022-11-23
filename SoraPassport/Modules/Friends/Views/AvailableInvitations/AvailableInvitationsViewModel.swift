import Foundation

protocol AvailableInvitationsViewModelProtocol {
}

struct AvailableInvitationsViewModel: AvailableInvitationsViewModelProtocol {
    var accountAddress: String
    var invitationCount: Decimal
    var bondedAmount: Decimal
    var delegate: AvailableInvitationsCellDelegate
}

extension AvailableInvitationsViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return AvailableInvitationsCell.reuseIdentifier
    }
}
