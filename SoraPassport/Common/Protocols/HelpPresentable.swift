import Foundation

protocol HelpPresentable: class {
    func presentHelp(from view: ControllerBackedProtocol?)
}

extension HelpPresentable {
    func presentHelp(from view: ControllerBackedProtocol?) {
        let url = ApplicationConfig.shared.faqURL
        let webViewController = WebViewFactory.createWebViewController(for: url,
                                                                       style: .automatic)

        view?.controller.present(webViewController, animated: true, completion: nil)
    }
}
