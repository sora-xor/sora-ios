import Foundation
import SSFCloudStorage

protocol OnboardingMainViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {

}

protocol OnboardingMainPresenterProtocol: AlertPresentable {
    func setup()
    func activateSignup()
    func activateAccountRestore()
    func activateCloudStorageConnection()
}

protocol OnboardingMainInteractorInputProtocol: AnyObject {
    func setup()
    func getBackupedAccounts(completion: @escaping (Result<[OpenBackupAccount], Error>) -> Void)
}

protocol OnboardingMainInteractorOutputProtocol: AnyObject {
    func didSuggestKeystoreImport()
}

protocol OnboardingMainWireframeProtocol: WebPresentable, ErrorPresentable, AlertPresentable, Loadable {
    func showSignup(from view: OnboardingMainViewProtocol?, isGoogleBackupSelected: Bool)
    func showAccountRestore(from view: OnboardingMainViewProtocol?)
    func showAccountRestoreRedesign(from view: OnboardingMainViewProtocol?, sourceType: AccountImportSource)
    func showKeystoreImport(from view: OnboardingMainViewProtocol?)
    func showBackupedAccounts(from view: OnboardingMainViewProtocol?, accounts: [OpenBackupAccount])
}
