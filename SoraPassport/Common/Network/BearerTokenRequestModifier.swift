import Foundation
import RobinHood
import SoraKeystore

final class BearerTokenRequestModifier {
    let token: String

    init(token: String) {
        self.token = token
    }
}

extension BearerTokenRequestModifier: NetworkRequestModifierProtocol {
    func modify(request: URLRequest) throws -> URLRequest {
        var modifiedRequest = request
        modifiedRequest.setValue("Bearer \(token)",
            forHTTPHeaderField: HttpHeaderKey.authorization.rawValue)

        return modifiedRequest
    }
}
