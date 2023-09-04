import CoreGraphics
import UIKit
import Combine

protocol ReferrerLinkViewModelProtocol {
    var isEnabled: Bool? { get}
    var interactor: InputLinkInteractorInputProtocol? { get }
}

final class ReferrerLinkViewModel: ReferrerLinkViewModelProtocol {
    
    @Published var isEnabled: Bool?
    weak var interactor: InputLinkInteractorInputProtocol?
    var address: String = ""

    init(isEnabled: Bool?,
         interactor: InputLinkInteractorInputProtocol?) {
        self.isEnabled = isEnabled
        self.interactor = interactor
    }
    
    func userChangeTextField(with text: String) {
        address = text.components(separatedBy: "/").last ?? ""
        let isCurrentUser = interactor?.isCurrentUserAddress(with: address) ?? false
        let isEnableButton = !isCurrentUser && (interactor?.getAccountId(from: address) != nil)
        isEnabled = isEnableButton
    }
    
    func userTappedOnActivate() {
        guard let accountId = interactor?.getAccountId(from: address)?.toHex(includePrefix: true) else { return }
        interactor?.sendSetReferrerRequest(with: accountId)
    }
}

extension ReferrerLinkViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return ReferrerLinkCell.reuseIdentifier
    }
}

