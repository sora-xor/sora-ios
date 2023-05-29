import Foundation

protocol ErrorPresentable: AnyObject {
    func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool
    func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool
}
