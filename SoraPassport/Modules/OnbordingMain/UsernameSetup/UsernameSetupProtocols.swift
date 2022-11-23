import SoraFoundation

protocol UsernameSetupViewProtocol: ControllerBackedProtocol {
    func set(viewModel: InputViewModelProtocol)
}

protocol UsernameSetupPresenterProtocol: AnyObject {
    var userName: String? { get set }
    func setup()
    func proceed()
    func endEditing()
    func activateURL(_ url: URL)
}

protocol UsernameSetupWireframeProtocol: AlertPresentable, WebPresentable {
    func proceed(from view: UsernameSetupViewProtocol?, username: String)
}

protocol UsernameSetupViewFactoryProtocol: AnyObject {
	static func createViewForOnboarding() -> UsernameSetupViewProtocol?
    static func createViewForAdding() -> UsernameSetupViewProtocol?
    static func createViewForAdding(endEditingBlock: (() -> Void)?) -> UsernameSetupViewProtocol?
}
