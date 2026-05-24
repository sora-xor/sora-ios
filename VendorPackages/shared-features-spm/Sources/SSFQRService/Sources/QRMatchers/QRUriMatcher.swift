import Foundation

public final class QRUriMatcherImpl: QRMatcher {
    private let scheme: String

    public init(scheme: String) {
        self.scheme = scheme
    }

    public func match(code: String) -> QRMatcherType? {
        guard let url = URL(string: code), url.scheme == scheme else {
            return nil
        }

        return .walletConnect(code)
    }
}
