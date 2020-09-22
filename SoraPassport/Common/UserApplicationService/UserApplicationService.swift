import Foundation

protocol UserApplicationServiceProtocol {
    func setup()
    func throttle()
}

protocol UserApplicationServiceFactoryProtocol {
    func createServices() -> [UserApplicationServiceProtocol]
}
