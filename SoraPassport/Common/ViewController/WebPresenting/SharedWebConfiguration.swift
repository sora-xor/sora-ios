import WebKit

final class SharedWebConfiguration {
    static let processPool = WKProcessPool()

    static var configuration: WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = processPool

        return configuration
    }
}
