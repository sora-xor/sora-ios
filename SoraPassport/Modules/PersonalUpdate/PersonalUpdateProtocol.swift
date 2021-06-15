import Foundation
import SoraFoundation

// MARK: - View

protocol PersonalUpdateViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [InputViewModelProtocol])
    func didStartSaving()
    func didCompleteSaving(success: Bool)
}

// MARK: - Presenter

protocol PersonalUpdatePresenterProtocol: class {
    func setup()
    func save()
}

// MARK: - Interactor

protocol PersonalUpdateInteractorInputProtocol: class {
    func setup()
    func update(username: String?)
}

protocol PersonalUpdateInteractorOutputProtocol: class {
    func didReceive(username: String?)
    func didUpdate(username: String?)
}

// MARK: - Wireframe

protocol PersonalUpdateWireframeProtocol: ErrorPresentable, AlertPresentable {
    func close(view: PersonalUpdateViewProtocol?)
}

// MARK: - Factory

protocol PersonalUpdateViewFactoryProtocol: class {
    static func createView() -> PersonalUpdateViewProtocol?
}
