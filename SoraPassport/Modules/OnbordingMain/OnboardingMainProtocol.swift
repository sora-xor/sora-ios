import Foundation

protocol OnboardingMainViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {

}

protocol OnboardingMainPresenterProtocol: class {
    func setup()
    func activateSignup()
    func activateAccountRestore()
}

protocol OnboardingMainInteractorInputProtocol: class {
    func setup()
}

protocol OnboardingMainInteractorOutputProtocol: class {
    func didSuggestKeystoreImport()
}

protocol OnboardingMainWireframeProtocol: WebPresentable, ErrorPresentable,
AlertPresentable, UnsupportedVersionPresentable {
    func showSignup(from view: OnboardingMainViewProtocol?)
    func showAccountRestore(from view: OnboardingMainViewProtocol?)
    func showKeystoreImport(from view: OnboardingMainViewProtocol?)
}

protocol OnboardingMainViewFactoryProtocol: WebPresentable {
    static func createViewForOnboarding() -> OnboardingMainViewProtocol?
}
