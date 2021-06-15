protocol AboutViewProtocol: ControllerBackedProtocol {
    func didReceive(optionViewModels: [AboutOptionViewModelProtocol])
}

protocol AboutPresenterProtocol: class {
    func setup()
    func activateOption(_ option: AboutOption)
}

protocol AboutWireframeProtocol: WebPresentable, EmailPresentable, AlertPresentable {

}

protocol AboutViewFactoryProtocol: class {
	static func createView() -> AboutViewProtocol?
}
