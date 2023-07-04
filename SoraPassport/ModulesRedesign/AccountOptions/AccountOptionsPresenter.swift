import Foundation
import SSFCloudStorage
import UIKit
import SoraUIKit

enum BackupState {
    case backedUp
    case notBackedUp
    
    var optionTitle: String {
        switch self {
        case .backedUp: return R.string.localizable.accountOptionsDeleteBackup(preferredLanguages: .currentLocale)
        case .notBackedUp: return R.string.localizable.accountOptionsBackupGoogle(preferredLanguages: .currentLocale)
        }
    }

    var optionTitleColor: SoramitsuColor {
        switch self {
        case .backedUp: return .statusError
        case .notBackedUp: return .fgPrimary
        }
    }
}

final class AccountOptionsPresenter {
    weak var view: AccountOptionsViewProtocol?
    var wireframe: AccountOptionsWireframeProtocol!
    var interactor: AccountOptionsInteractorInputProtocol!
    private var appEventService = AppEventService()
    private var backupState: BackupState {
        didSet {
            view?.setupOptions(with: backupState)
        }
    }

    init(backupState: BackupState) {
        self.backupState = backupState
    }
}

extension AccountOptionsPresenter: AccountOptionsPresenterProtocol {
    func setup() {
        view?.didReceive(username: interactor.currentAccount.username, hasEntropy: interactor.accountHasEntropy)
        view?.didReceive(address: interactor.currentAccount.address)
        view?.setupOptions(with: backupState)
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
    
    func deleteBackup() {
        interactor.deleteBackup { [weak self] error in
            guard let error = error else {
                self?.backupState = .notBackedUp
                return
            }
            self?.view?.present(message: nil,
                                title: error.localizedDescription,
                                closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                                from: self?.view)
        }
    }
    
    func createBackup() {
        interactor.signInToGoogleIfNeeded { [weak self] account in
           
            self?.wireframe?.setupBackupAccountPassword(on: self?.view, account: account, completion: { [weak self] in
                guard let self = self else { return }
                self.backupState = ApplicationConfig.shared.backupedAccountAddresses.contains(account.address) ? .backedUp : .notBackedUp
                self.view?.setupOptions(with: self.backupState)
            })
        }
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
