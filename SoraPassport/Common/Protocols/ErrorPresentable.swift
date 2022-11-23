import Foundation

protocol ErrorPresentable: class {
    func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool
}
