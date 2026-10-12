import Foundation

public protocol NetworkClientFactory {
    func buildNetworkClient(with type: NetworkClientType) -> NetworkClient
}

public final class BaseNetworkClientFactory: NetworkClientFactory {
    public init() {}

    public func buildNetworkClient(with type: NetworkClientType) -> NetworkClient {
        switch type {
        case .plain:
            return RESTNetworkClient(session: URLSession.shared)
        case let .custom(client):
            return client
        }
    }
}
