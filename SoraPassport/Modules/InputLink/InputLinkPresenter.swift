import Foundation
import UIKit

protocol InputLinkPresenterOutput: AnyObject {
    func setupReferrer(_ referrer: String)
    func showAlert(withSuccess isSuccess: Bool)
    func showTransactionDetails(from controller: UIViewController?, result: Result<String, Swift.Error>, peerAddress: String, completion: (() -> Void)?)
}

final class InputLinkPresenter {
    weak var view: InputLinkViewInput?
    weak var output: InputLinkPresenterOutput?
    var interactor: InputLinkInteractorInputProtocol?
    weak var viewModel: ReferrerLinkViewModel?

    private var items: [CellViewModel] = []
    private var actionButtonIsEnabled: Bool = false
}

extension InputLinkPresenter: InputLinkViewOutput {
    func willMove() {
        let item = ReferrerLinkViewModel(isEnabled: actionButtonIsEnabled,
                                         interactor: interactor)
        items.append(item)
        
        DispatchQueue.main.async {
            self.view?.setup(with: self.items)
        }
        
        viewModel = item
    }
}

extension InputLinkPresenter: InputLinkInteractorOutputProtocol {
    func setReferralRequestReceived(with result: Result<String, Error>) {
        DispatchQueue.main.async {
            guard let viewModel = self.viewModel else { return }
            
            if case .success = result {
                self.output?.setupReferrer(viewModel.address)
            }
            
            self.output?.showTransactionDetails(from: self.view?.controller,
                                                result: result,
                                                peerAddress: viewModel.address,
                                                completion: {
                self.view?.dismiss(with: {})
            })
        }
    }
}
