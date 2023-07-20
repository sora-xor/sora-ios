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
                                           interactor: interactor))
        
        DispatchQueue.main.async {
            self.view?.setup(with: self.items)
        }
        
        self.actionButtonIsEnabled = actionButtonIsEnabled
    }
}

extension InputLinkPresenter: InputLinkInteractorOutputProtocol {
    func setReferralRequestReceived(withSuccess isSuccess: Bool) {
        DispatchQueue.main.async {
            self.view?.dismiss { [weak self] in
                guard
                    let self = self,
                    let viewModel = items.first(where: {$0 is ReferrerLinkViewModel}) as? ReferrerLinkViewModel
                else { return }
                self.address = viewModel.address
                self.output?.setupReferrer(viewModel.address)
                self.output?.showAlert(withSuccess: isSuccess)
            }
        }
    }
}
