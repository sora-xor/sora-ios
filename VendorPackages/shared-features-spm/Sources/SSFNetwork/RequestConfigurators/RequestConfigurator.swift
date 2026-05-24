import Foundation

public protocol RequestConfigurator {
    func buildRequest(with config: RequestConfig) throws -> URLRequest
}
