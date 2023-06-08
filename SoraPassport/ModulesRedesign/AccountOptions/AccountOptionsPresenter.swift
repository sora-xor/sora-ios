import Foundation
import UIKit

final class AccountOptionsPresenter {
    weak var view: AccountOptionsViewProtocol?
    var wireframe: AccountOptionsWireframeProtocol!
    var interactor: AccountOptionsInteractorInputProtocol!
    private var appEventService = AppEventService()
}

extension AccountOptionsPresenter: AccountOptionsPresenterProtocol {
    func setup() {
        view?.didReceive(username: interactor.currentAccount.username, hasEntropy: interactor.accountHasEntropy)
        view?.didReceive(address: interactor.currentAccount.address)
    }

    func didUpdateUsername(_ new: String) {
        interactor.updateUsername(new)
    }

    func showPassphrase() {
        wireframe.showPassphrase(from: view, account: interactor.currentAccount)
    }

    func showRawSeed() {
        wireframe.showRawSeed(from: view, account: interactor.currentAccount)
    }

    func showJson() {
        wireframe.showJson(account: interactor.currentAccount, from: view)
    }
    
    func doLogout() {
        interactor.isLastAccountWithCustomNodes { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.wireframe.showLogout(from: self.view, isNeedCustomNodeText: result, completionBlock: self.interactor.logoutAndClean)
            }
        }
    }

    func close() {
        wireframe.back(from: self.view)
    }

    func restart() {
        wireframe.showRoot()
    }
    
    func copyToClipboard() {
        let title = NSAttributedString(string: R.string.localizable.commonCopied(preferredLanguages: .currentLocale))
        let viewModel = AppEventViewController.ViewModel(title: title)
        let appEventController = AppEventViewController(style: .custom(viewModel))
        appEventService.showToasterIfNeeded(viewController: appEventController)
        UIPasteboard.general.string = interactor.currentAccount.address
    }
}

extension AccountOptionsPresenter: AccountOptionsInteractorOutputProtocol {}
