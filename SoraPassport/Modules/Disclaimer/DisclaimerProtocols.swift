import Foundation

protocol DisclaimerViewProtocol: ControllerBackedProtocol {
    
}

protocol DisclaimerViewFactoryProtocol {
    func createView() -> DisclaimerViewProtocol?
}
