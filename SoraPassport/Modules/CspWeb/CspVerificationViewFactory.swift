import Foundation
import WebKit

final class CspVerificationViewFactory: CspWebViewFactoryProtocol {
    static func createVerificationView() -> WebPresentingViewProtocol? {
        let request = URLRequest(url: ApplicationConfig.shared.cspExternalInfo.verificationUrl)

        let configuration = WKWebViewConfiguration()
        configuration.processPool = SharedWebConfiguration.processPool

        let view = WebViewController(configuration: configuration, request: request)
        view.title = R.string.localizable.verifyIdentityTitle()

        return view
    }

    static func createSignupView() -> WebPresentingViewProtocol? {
        let request = URLRequest(url: ApplicationConfig.shared.cspExternalInfo.signupUrl)

        let configuration = WKWebViewConfiguration()
        configuration.processPool = SharedWebConfiguration.processPool

        let view = WebViewController(configuration: configuration, request: request)
        view.title = R.string.localizable.lykkeWebSignUpTitle()

        return view
    }
}
