import Foundation

protocol InvitedViewModelProtocol: class {
    var fullName: String { get }
}

class InvitedViewModel: InvitedViewModelProtocol {
    var fullName: String

    init(fullName: String) {
        self.fullName = fullName
    }
}
