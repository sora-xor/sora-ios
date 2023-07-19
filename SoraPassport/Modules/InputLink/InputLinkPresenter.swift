import Foundation

protocol InputLinkPresenterOutput: AnyObject {
    func setupReferrer(_ referrer: String)
    func showAlert(withSuccess isSuccess: Bool)
}

final class InputLinkPresenter {
    weak var view: InputLinkViewInput?
    weak var output: InputLinkPresenterOutput?
    var interactor: InputLinkInteractorInputProtocol?

    private var items: [CellViewModel] = []
    private var actionButtonIsEnabled: Bool = false
    private var address: String = ""
}

extension InputLinkPresenter: InputLinkViewOutput {
    func willMove() {
        let actionButtonIsEnabled = !address.isEmpty
        
        items.append(ReferrerLinkViewModel(isEnabled: actionButtonIsEnabled,
                                           delegate: self))
        
        DispatchQueue.main.async {
            self.view?.setup(with: self.items)
        }
        
        self.actionButtonIsEnabled = actionButtonIsEnabled
    }
}

extension InputLinkPresenter: ReferrerLinkCellDelegate {
    func userTappedonActivete(with text: String) {
        guard let accountId = interactor?.getAccountId(from: address)?.toHex(includePrefix: true) else { return }
        interactor?.sendSetReferrerRequest(with: accountId)
    }

    func userChangeTextField(with text: String) {
        address = text.components(separatedBy: "/").last ?? ""
        let isCurrentUser = interactor?.isCurrentUserAddress(with: address) ?? false
        let isEnableButton = !isCurrentUser && (interactor?.getAccountId(from: address) != nil)
        setActionButtonEnabled(isEnableButton)
    }
}

extension InputLinkPresenter: InputLinkInteractorOutputProtocol {
    func setReferralRequestReceived(withSuccess isSuccess: Bool) {
        DispatchQueue.main.async {
            self.view?.dismiss { [weak self] in
                guard let self = self else { return }
                self.output?.setupReferrer(self.address)
                self.output?.showAlert(withSuccess: isSuccess)
            }
        }
    }
    
    private func setActionButtonEnabled(_ isEnabled: Bool) {
        guard let buttonCellRow = items.firstIndex(where: { $0 is ReferrerLinkViewModel }),
                self.actionButtonIsEnabled != isEnabled else { return }

        (items[buttonCellRow] as? ReferrerLinkViewModel)?.isEnabled = isEnabled

        self.actionButtonIsEnabled = isEnabled

        let buttonCellIndexPath = IndexPath(row: buttonCellRow, section: 0)
        self.view?.reloadCell(at: buttonCellIndexPath, models: items)
    }
}
