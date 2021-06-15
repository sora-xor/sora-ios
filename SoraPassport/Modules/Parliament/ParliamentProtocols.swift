protocol ParliamentViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: ComingSoonViewModel)
}

protocol ParliamentPresenterProtocol: class {
    func setup(preferredLocalizations languages: [String]?)
    func activateReferenda()
}

protocol ParliamentInteractorInputProtocol: class {

}

protocol ParliamentInteractorOutputProtocol: class {

}

protocol ParliamentWireframeProtocol: class {
    func showReferendaView(from view: ParliamentViewProtocol?)
}

protocol ParliamentViewFactoryProtocol: class {
	static func createView() -> ParliamentViewProtocol?
}
