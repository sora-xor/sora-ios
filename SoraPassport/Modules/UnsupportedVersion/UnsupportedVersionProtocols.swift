import UIKit

protocol UnsupportedVersionViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: UnsupportedVersionViewModel)
}

protocol UnsupportedVersionPresenterProtocol: class {
    func setup()
    func performAction()
}

protocol UnsupportedVersionInteractorInputProtocol: class {}

protocol UnsupportedVersionInteractorOutputProtocol: class {}

protocol UnsupportedVersionWireframeProtocol: OutboundUrlPresentable, AlertPresentable {}

protocol UnsupportedVersionViewFactoryProtocol: class {
    static func createView(supportedVersionData: SupportedVersionData) -> UnsupportedVersionViewProtocol?
}
