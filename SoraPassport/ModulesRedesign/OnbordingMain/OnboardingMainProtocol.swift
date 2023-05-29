import Foundation

protocol OnboardingMainViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {

}

protocol OnboardingMainPresenterProtocol: AlertPresentable {
    func setup()
    func activateSignup()
    func activateAccountRestore()
}

protocol OnboardingMainInteractorInputProtocol: AnyObject {
    func setup()
}

protocol OnboardingMainInteractorOutputProtocol: AnyObject {
    func didSuggestKeystoreImport()
}

protocol OnboardingMainWireframeProtocol: WebPresentable, ErrorPresentable, AlertPresentable {
    func showSignup(from view: OnboardingMainViewProtocol?)
    func showAccountRestore(from view: OnboardingMainViewProtocol?)
    func showAccountRestoreRedesign(from view: OnboardingMainViewProtocol?, sourceType: AccountImportSource)
    func showKeystoreImport(from view: OnboardingMainViewProtocol?)
}
