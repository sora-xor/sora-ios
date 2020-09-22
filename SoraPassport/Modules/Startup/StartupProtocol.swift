import Foundation

protocol StartupViewProtocol: ControllerBackedProtocol {
    func didUpdate(title: String, subtitle: String)
}

protocol StartupPresenterProtocol: class {
    func setup()
}

enum StartupInteratorState {
    case initial
    case unsupported
    case verifying
    case waitingRetry
    case completed
}

protocol StartupInteractorInputProtocol: class {
    var state: StartupInteratorState { get }

    func verify()
}

protocol StartupInteractorOutputProtocol: class {
    func didDecideOnboarding()
    func didDecidePincodeSetup()
    func didDecideMain()
    func didDecideUnsupportedVersion(data: SupportedVersionData)
    func didChangeState()
}

protocol StartupWireframeProtocol: UnsupportedVersionPresentable {
    func showOnboarding(from view: StartupViewProtocol?)
    func showMain(from view: StartupViewProtocol?)
    func showPincodeSetup(from view: StartupViewProtocol?)
}

protocol StartupViewFactoryProtocol: class {
	static func createView() -> StartupViewProtocol?
}
