import SoraFoundation

protocol UsernameSetupViewProtocol: ControllerBackedProtocol {
    func set(viewModel: InputViewModelProtocol)
}

protocol UsernameSetupPresenterProtocol: class {
    var userName: String? { get set }
    func setup()
    func proceed()
    func activateURL(_ url: URL)
}

protocol UsernameSetupWireframeProtocol: AlertPresentable, WebPresentable {
    func proceed(from view: UsernameSetupViewProtocol?, username: String)
}

protocol UsernameSetupViewFactoryProtocol: class {
	static func createViewForOnboarding() -> UsernameSetupViewProtocol?
    static func createViewForAdding() -> UsernameSetupViewProtocol?
}
