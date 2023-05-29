import Foundation
import CommonWallet
import RobinHood
/*
final class WalletNetworkResolverMock: MiddlewareNetworkResolverProtocol {
    var closureUrlResolver: ((MiddlewareRequestType) -> String)?
    var closureAdapter: ((MiddlewareRequestType) -> NetworkRequestModifierProtocol?)?
    var closureErrorFactory: ((MiddlewareRequestType) -> MiddlewareNetworkErrorFactoryProtocol?)?

    init(urlResolver: @escaping (MiddlewareRequestType) -> String) {
        closureUrlResolver = urlResolver
    }

    func urlTemplate(for type: MiddlewareRequestType) -> String {
        return closureUrlResolver?(type) ?? ""
    }

    func adapter(for type: MiddlewareRequestType) -> NetworkRequestModifierProtocol? {
        return closureAdapter?(type)
    }

    func errorFactory(for type: MiddlewareRequestType) -> MiddlewareNetworkErrorFactoryProtocol? {
        return closureErrorFactory?(type)
    }
}
*/
