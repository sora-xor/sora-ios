import Foundation

protocol LanguageViewProtocol: ControllerBackedProtocol {
    var presenter: LanguagePresenterProtocol? { get set }
    
    func update(model: LanguageModel)
    func updateHierarchy()
}

protocol LanguagePresenterProtocol: AnyObject {
    var view: LanguageViewProtocol? { get set }
    
    func reload()
}

protocol LanguageWireframeProtocol: ErrorPresentable, AlertPresentable, HelpPresentable, WebPresentable {
}
